import 'dart:developer' as developer;

import '../../models/bank_transaction.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result returned by parser
// ─────────────────────────────────────────────────────────────────────────────
class ParsedStatementResult {
  const ParsedStatementResult({
    required this.supported,
    required this.bankName,
    required this.bankFormat,
    required this.fromDate,
    required this.toDate,
    required this.accountNumber,
    required this.accountHolder,
    required this.ifscCode,
    required this.transactions,
    this.openingBalance = 0,
    this.errorMessage,
  });

  final bool supported;
  final String bankName;
  final String bankFormat; // e.g. 'AXIS_PDF_V1'
  final DateTime fromDate;
  final DateTime toDate;
  final String accountNumber;
  final String accountHolder;
  final String ifscCode;
  final List<BankTransaction> transactions;
  final double openingBalance;
  final String? errorMessage;

  /// Summary stats derived from transactions
  int get transactionCount => transactions.length;

  double get totalCredits => transactions
      .where((t) => t.type == 'CREDIT')
      .fold<double>(0, (sum, t) => sum + t.amount);

  double get totalDebits => transactions
      .where((t) => t.type == 'DEBIT')
      .fold<double>(0, (sum, t) => sum + t.amount);

  double get averageMonthlyCredit {
    if (transactions.isEmpty) return 0;
    final months = toDate.difference(fromDate).inDays / 30.0;
    return months > 0 ? totalCredits / months : 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bank Statement Parser — Axis Bank PDF text format (V1)
// Template: Account_stmt_XX3901_15012026.pdf (Axis Savings/Priority)
//
// Format rules observed from sample:
//   Header: "Statement of Axis Account No :XXXXXXXXXXX for the period (From : DD-MM-YYYY  To : DD-MM-YYYY)"
//   Column headers: Tran Date | Chq No | Particulars | Debit | Credit | Balance | Init. | Br
//   Date line: DD-MM-YYYY
//   Description: 1–3 continuation lines (wrapped)
//   Debit transaction: [amount, balance]  (2 numerics)
//   Credit transaction: [amount, balance] but balance > previous_balance
//   Branch code line: 3-digit number like "345"
//
// Credit vs Debit detection strategy:
//   If balance_after > (previous_balance + 0.01) → CREDIT, amount = balance_after - previous_balance
//   Otherwise → DEBIT, amount = previous_balance - balance_after
// ─────────────────────────────────────────────────────────────────────────────
class BankStatementParser {
  static const List<String> _supportedBanks = <String>['AXIS', 'SBI', 'HDFC', 'ICICI'];

  // ── Public entry points ────────────────────────────────────────────────────

  /// Parse raw text extracted from a PDF statement.
  /// Use with packages like syncfusion_flutter_pdf or pdfx to extract text first.
  ParsedStatementResult parseText({
    required String rawText,
    required String bankName,
  }) {
    final normalized = _normalizeBankName(bankName);

    if (!_supportedBanks.contains(normalized)) {
      return _unsupported(normalized,
          'Bank format for "$bankName" is not yet supported.\nSupported: ${_supportedBanks.join(', ')}.');
    }

    try {
      switch (normalized) {
        case 'AXIS':
          return _parseAxis(rawText);
        case 'SBI':
          return _parseSbi(rawText);
        default:
          return _parseGenericFallback(rawText, normalized);
      }
    } catch (e, stack) {
      developer.log('BankStatementParser error for $normalized', error: e, stackTrace: stack);
      return _unsupported(normalized, 'Parsing failed: ${e.runtimeType}. Please retry with a cleaner PDF.');
    }
  }

  /// Validate statement period: must cover ≥6 months and end within last 30 days.
  bool isStatementPeriodValid({
    required DateTime fromDate,
    required DateTime toDate,
    required DateTime currentDate,
  }) {
    final days = toDate.difference(fromDate).inDays;
    final recencyDays = currentDate.difference(toDate).inDays;
    final hasSixMonths = days >= 180;
    final recentEnough = recencyDays <= 30;
    return hasSixMonths && recentEnough;
  }

  // ── Axis Bank PDF V1 parser ────────────────────────────────────────────────

  ParsedStatementResult _parseAxis(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .toList(growable: false);

    // Extract header metadata
    String accountNumber = '';
    String accountHolder = '';
    String ifscCode = '';
    DateTime fromDate = DateTime(2000);
    DateTime toDate = DateTime(2000);

    for (final line in lines) {
      if (_isAxisAccountLine(line)) {
        final meta = _parseAxisAccountLine(line);
        accountNumber = meta['account'] ?? '';
        fromDate = _parseDate(meta['from'] ?? '') ?? DateTime(2000);
        toDate = _parseDate(meta['to'] ?? '') ?? DateTime(2000);
      }
      if (line.startsWith('IFSC Code :')) {
        ifscCode = line.replaceAll('IFSC Code :', '').trim();
      }
    }

    if (ifscCode.isEmpty) {
      ifscCode = _firstGroup(RegExp(r'\b[A-Z]{4}0[A-Z0-9]{6}\b'), rawText, group: 0);
    }

    // Account holder is first non-blank line
    for (final line in lines) {
      if (line.isNotEmpty &&
          !line.startsWith('Joint') &&
          !line.startsWith('Customer') &&
          RegExp(r'^[A-Z\s]+$').hasMatch(line) &&
          line.length > 3) {
        accountHolder = line.trim();
        break;
      }
    }

    // Extract opening balance
    double openingBalance = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i] == 'OPENING BALANCE' && i + 1 < lines.length) {
        openingBalance = _parseAmount(lines[i + 1]) ?? 0;
        break;
      }
    }

    // Parse transactions
    var transactions = _parseAxisTransactions(lines, openingBalance);
    if (transactions.isEmpty) {
      transactions = _parseGenericRowsFromRaw(rawText);
    }

    if (transactions.isEmpty) {
      return _unsupported('AXIS', 'Could not parse Axis statement transactions from OCR text.');
    }

    developer.log(
      'AxisParser: parsed ${transactions.length} transactions '
      'from $fromDate to $toDate, account: $accountNumber',
    );

    return ParsedStatementResult(
      supported: true,
      bankName: 'Axis Bank',
      bankFormat: 'AXIS_PDF_V1',
      fromDate: fromDate,
      toDate: toDate,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      ifscCode: ifscCode,
      openingBalance: openingBalance,
      transactions: transactions,
    );
  }

  List<BankTransaction> _parseAxisTransactions(List<String> lines, double openingBalance) {
    final transactions = <BankTransaction>[];
    final dateRe = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    final amountRe = RegExp(r'[\d,]*\.\d{1,2}');

    double previousBalance = openingBalance;

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      if (!dateRe.hasMatch(line)) {
        i++;
        continue;
      }

      // Found a date line
      final dateStr = line;
      final date = _parseDate(dateStr);
      if (date == null) { i++; continue; }
      i++;

      // Collect all lines until next date marker to form one transaction block.
      final blockParts = <String>[];
      while (i < lines.length &&
          !dateRe.hasMatch(lines[i]) &&
          lines[i] != 'OPENING BALANCE' &&
          lines[i] != '++++ End of Statement ++++') {
        if (lines[i].isNotEmpty) {
          blockParts.add(lines[i]);
        }
        i++;
      }
      final block = blockParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (block.isEmpty) {
        continue;
      }

      final numericValues = amountRe
          .allMatches(block)
          .map((m) => _parseAmount(m.group(0) ?? ''))
          .whereType<double>()
          .toList(growable: false);

      final description = block
          .replaceAll(amountRe, ' ')
          .replaceAll(RegExp(r'\b\d{3,4}\b$'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (numericValues.length < 2 || description.isEmpty) continue;

      // Last value is always balance_after
      final balanceAfter = numericValues.last;
      final amount = numericValues.first;

      // Credit vs Debit: if balance went up → CREDIT, else DEBIT
      final String type;
      final double txnAmount;

      if (balanceAfter > previousBalance + 0.009) {
        type = 'CREDIT';
        txnAmount = (balanceAfter - previousBalance).abs();
      } else {
        type = 'DEBIT';
        txnAmount = amount; // first value is the debit amount
      }

      previousBalance = balanceAfter;

      transactions.add(BankTransaction(
        date: date,
        description: description,
        amount: txnAmount,
        type: type,
        balanceAfter: balanceAfter,
      ));
    }

    return transactions;
  }

  // ── SBI parser (stub skeleton — to be expanded with real SBI PDF sample) ──

  ParsedStatementResult _parseSbi(String rawText) {
    final lines = _tokenizedLines(rawText);
    var transactions = _parseGenericFallbackList(lines, 'SBI');
    if (transactions.isEmpty) {
      transactions = _parseGenericRowsFromRaw(rawText);
    }
    if (transactions.isEmpty) {
      return _unsupported('SBI', 'Could not parse SBI transactions from OCR text.');
    }

    final accountNumber = _firstGroup(
      RegExp(r'(?:(?:a\/c|account)\s*(?:no|number)?\s*[:\-]?\s*)([0-9Xx]{8,18})', caseSensitive: false),
      rawText,
    );
    final accountHolder = _firstGroup(
      RegExp(r'(?:(?:account\s*holder|customer\s*name|name)\s*[:\-]?\s*)([A-Z][A-Z\s\.]{3,60})', caseSensitive: false),
      rawText,
    );
    final ifsc = _firstGroup(RegExp(r'\b[A-Z]{4}0[A-Z0-9]{6}\b'), rawText);

    final dates = transactions.map((t) => t.date).toList(growable: false)..sort();

    return ParsedStatementResult(
      supported: true,
      bankName: 'State Bank of India',
      bankFormat: 'SBI_PDF_V1',
      fromDate: dates.first,
      toDate: dates.last,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      ifscCode: ifsc,
      openingBalance: transactions.first.balanceAfter,
      transactions: transactions,
    );
  }

  // ── Generic fallback (best-effort) ────────────────────────────────────────

  ParsedStatementResult _parseGenericFallback(String rawText, String bankName) {
    final lines = _tokenizedLines(rawText);
    var transactions = _parseGenericFallbackList(lines, bankName);
    if (transactions.isEmpty) {
      transactions = _parseGenericRowsFromRaw(rawText);
    }
    final hasTransactions = transactions.isNotEmpty;

    final dates = transactions.map((t) => t.date).toList(growable: false)..sort();
    final accountNumber = _firstGroup(
      RegExp(r'(?:(?:a\/c|account)\s*(?:no|number)?\s*[:\-]?\s*)([0-9Xx]{8,18})', caseSensitive: false),
      rawText,
    );
    final ifsc = _firstGroup(RegExp(r'\b[A-Z]{4}0[A-Z0-9]{6}\b'), rawText);
    final accountHolder = _firstGroup(
      RegExp(r'(?:(?:account\s*holder|customer\s*name|name)\s*[:\-]?\s*)([A-Z][A-Z\s\.]{3,60})', caseSensitive: false),
      rawText,
    );

    return ParsedStatementResult(
      supported: hasTransactions,
      bankName: bankName,
      bankFormat: 'GENERIC_FALLBACK',
      fromDate: hasTransactions ? dates.first : DateTime(2000),
      toDate: hasTransactions ? dates.last : DateTime(2000),
      accountNumber: accountNumber,
      accountHolder: accountHolder,
      ifscCode: ifsc,
      openingBalance: transactions.isNotEmpty ? transactions.first.balanceAfter : 0.0,
      transactions: transactions,
      errorMessage: hasTransactions ? null : 'Could not parse transactions from this statement.',
    );
  }

  String _normalizeBankName(String bankName) {
    final normalized = bankName.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.contains('AXIS')) {
      return 'AXIS';
    }
    if (normalized == 'SBI' || normalized.contains('STATE BANK')) {
      return 'SBI';
    }
    if (normalized == 'HDFC' || normalized.contains('HDFC')) {
      return 'HDFC';
    }
    if (normalized == 'ICICI' || normalized.contains('ICICI')) {
      return 'ICICI';
    }
    return normalized;
  }

  List<BankTransaction> _parseGenericFallbackList(List<String> lines, String logName) {
    final dateRe = RegExp(r'(\d{2}[/-]\d{2}[/-]\d{2,4})');
    final amountRe = RegExp(r'([\d,]+\.\d{2})');

    final transactions = <BankTransaction>[];
    double? lastBalance;

    for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final dateMatch = dateRe.firstMatch(line);
        if (dateMatch == null) continue;
        
        final date = _parseDate(dateMatch.group(1) ?? '');
        if (date == null) continue;

        // Find all contiguous amounts
        final matches = amountRe.allMatches(line).toList();
        if (matches.length < 2) continue;

        final balanceAfter = _parseAmount(matches.last.group(0) ?? '') ?? 0.0;
        final amount = _parseAmount(matches.first.group(0) ?? '') ?? 0.0;
        
        // Infer Type
        String type = 'DEBIT'; // Default fallback
        if (line.contains(' CR ') || line.endsWith('Cr')) {
            type = 'CREDIT';
        } else if (line.contains(' DR ') || line.endsWith('Dr')) {
            type = 'DEBIT';
        } else if (lastBalance != null) {
            // Infer from balance delta
            if (balanceAfter >= lastBalance + 0.009) {
                type = 'CREDIT';
            } else if (balanceAfter <= lastBalance - 0.009) {
                type = 'DEBIT';
            }
        }
        
        lastBalance = balanceAfter;

        transactions.add(BankTransaction(
            date: date,
            description: line.replaceAll(dateRe, '').replaceAll(amountRe, '').trim(),
            amount: amount,
            type: type,
            balanceAfter: balanceAfter,
        ));
    }
    return transactions;
  }

  List<BankTransaction> _parseGenericRowsFromRaw(String rawText) {
    final normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const <BankTransaction>[];
    }

    final datePattern = RegExp(r'\d{2}[/-]\d{2}[/-]\d{4}');
    final amountPattern = RegExp(r'[0-9,]+(?:\.\d{1,2})');
    final dateMatches = datePattern.allMatches(normalized).toList(growable: false);
    if (dateMatches.isEmpty) {
      return const <BankTransaction>[];
    }

    final transactions = <BankTransaction>[];
    double? previousBalance;

    for (var i = 0; i < dateMatches.length; i++) {
      final current = dateMatches[i];
      final dateRaw = current.group(0) ?? '';
      final date = _parseDate(dateRaw);
      if (date == null) {
        continue;
      }

      final segmentStart = current.end;
      final segmentEnd = i + 1 < dateMatches.length ? dateMatches[i + 1].start : normalized.length;
      if (segmentStart >= segmentEnd) {
        continue;
      }

      final segment = normalized.substring(segmentStart, segmentEnd).trim();
      if (segment.isEmpty) {
        continue;
      }

      final amountMatches = amountPattern.allMatches(segment).toList(growable: false);
      if (amountMatches.length < 2) {
        continue;
      }

      final amountRaw = amountMatches.first.group(0) ?? '';
      final balanceRaw = amountMatches.last.group(0) ?? '';
      final amount = _parseAmount(amountRaw) ?? 0.0;
      final balanceAfter = _parseAmount(balanceRaw) ?? 0.0;

      final description = segment.replaceAll(amountPattern, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (description.isEmpty) {
        continue;
      }

      var type = 'DEBIT';
      if (previousBalance != null && balanceAfter > previousBalance! + 0.009) {
        type = 'CREDIT';
      }

      transactions.add(BankTransaction(
        date: date,
        description: description,
        amount: amount,
        type: type,
        balanceAfter: balanceAfter,
      ));
      previousBalance = balanceAfter;
    }

    return transactions;
  }

  List<String> _tokenizedLines(String rawText) {
    final normalized = rawText.replaceAll('\r', '\n').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final withDateBreaks = normalized.replaceAllMapped(
      RegExp(r'(?<!\d)(\d{2}[/-]\d{2}[/-]\d{2,4})'),
      (m) => '\n${m.group(1)}',
    );
    return withDateBreaks
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
  }

  String _firstGroup(RegExp pattern, String input, {int group = 1}) {
    final match = pattern.firstMatch(input);
    if (match == null) {
      return '';
    }
    final value = match.group(group) ?? '';
    return value.trim();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isAxisAccountLine(String line) =>
      line.contains('Axis Account No') && line.contains('for the period');

  Map<String, String> _parseAxisAccountLine(String line) {
    final result = <String, String>{};

    final acctMatch = RegExp(r'Account No\s*:\s*(\d+)').firstMatch(line);
    if (acctMatch != null) result['account'] = acctMatch.group(1) ?? '';

    final fromMatch = RegExp(r'From\s*:\s*([\d-]+)').firstMatch(line);
    if (fromMatch != null) result['from'] = fromMatch.group(1) ?? '';

    final toMatch = RegExp(r'To\s*:\s*([\d-]+)').firstMatch(line);
    if (toMatch != null) result['to'] = toMatch.group(1) ?? '';

    return result;
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    // DD-MM-YYYY
    final re1 = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$');
    // DD/MM/YYYY
    final re2 = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

    RegExpMatch? m = re1.firstMatch(trimmed) ?? re2.firstMatch(trimmed);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(3)!), // year
        int.parse(m.group(2)!), // month
        int.parse(m.group(1)!), // day
      );
    } catch (_) {
      return null;
    }
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  ParsedStatementResult _unsupported(String bankName, String message) {
    return ParsedStatementResult(
      supported: false,
      bankName: bankName,
      bankFormat: 'UNSUPPORTED',
      fromDate: DateTime(2000),
      toDate: DateTime(2000),
      accountNumber: '',
      accountHolder: '',
      ifscCode: '',
      transactions: const <BankTransaction>[],
      errorMessage: message,
    );
  }
}

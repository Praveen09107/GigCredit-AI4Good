import 'dart:math';

enum BankTransactionType {
  credit,
  debit,
  unknown,
}

class BankTransaction {
  const BankTransaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    this.balance,
    this.tags = const <String>{},
  });

  final DateTime? date;
  final String description;
  final double amount;
  final BankTransactionType type;
  final double? balance;
  final Set<String> tags;
}

class EmiProfile {
  const EmiProfile({
    required this.activeEmiCount,
    required this.totalMonthlyEmi,
    required this.detectedLenders,
  });

  final int activeEmiCount;
  final double totalMonthlyEmi;
  final List<String> detectedLenders;
}

class TransactionEngineResult {
  const TransactionEngineResult({
    required this.transactions,
    required this.csv,
    required this.emiProfile,
    required this.utilityDebitCount,
    required this.insuranceDebitCount,
  });

  final List<BankTransaction> transactions;
  final String csv;
  final EmiProfile emiProfile;
  final int utilityDebitCount;
  final int insuranceDebitCount;
}

class TransactionEngine {
  const TransactionEngine();

  static final _dateRegex = RegExp(r'(\d{2}[-/]\d{2}[-/]\d{4})');
  static final _amountRegex = RegExp(r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})|[0-9]+(?:\.[0-9]{1,2})?)');

  static const _emiKeywords = <String>[
    'emi',
    'loan emi',
    'nach emi',
    'finance emi',
    'bajaj emi',
    'card emi',
    'bnpl emi',
  ];

  static const _utilityKeywords = <String>[
    'tneb',
    'electricity',
    'bill payment',
    'lpg',
    'gas',
    'mobile bill',
    'wifi',
    'broadband',
  ];

  static const _insuranceKeywords = <String>[
    'insurance',
    'premium',
    'policy',
    'lic',
    'vehicle insurance',
  ];

  TransactionEngineResult processBankStatementOcr(String ocrText) {
    final lines = ocrText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final transactions = <BankTransaction>[];
    for (final line in lines) {
      final parsed = _parseLine(line);
      if (parsed != null) {
        transactions.add(parsed);
      }
    }

    final tagged = transactions.map(_tagTransaction).toList(growable: false);
    final emiProfile = _detectRecurringEmi(tagged);
    final utilityDebitCount = tagged.where((tx) => tx.tags.contains('UTILITY_DEBIT')).length;
    final insuranceDebitCount = tagged.where((tx) => tx.tags.contains('INSURANCE_DEBIT')).length;

    return TransactionEngineResult(
      transactions: tagged,
      csv: _toCsv(tagged),
      emiProfile: emiProfile,
      utilityDebitCount: utilityDebitCount,
      insuranceDebitCount: insuranceDebitCount,
    );
  }

  BankTransaction? _parseLine(String line) {
    final dateMatch = _dateRegex.firstMatch(line);
    final amountMatches = _amountRegex.allMatches(line).toList(growable: false);
    if (amountMatches.isEmpty) {
      return null;
    }

    final amountRaw = amountMatches.last.group(0);
    if (amountRaw == null) {
      return null;
    }

    final amount = double.tryParse(amountRaw.replaceAll(',', ''));
    if (amount == null) {
      return null;
    }

    final description = line.replaceFirst(_dateRegex, '').trim();
    final type = _inferType(description);

    return BankTransaction(
      date: _parseDate(dateMatch?.group(0)),
      description: description,
      amount: amount,
      type: type,
    );
  }

  DateTime? _parseDate(String? rawDate) {
    if (rawDate == null) {
      return null;
    }
    final normalized = rawDate.replaceAll('/', '-');
    final parts = normalized.split('-');
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime(year, month, day);
  }

  BankTransactionType _inferType(String description) {
    final lower = description.toLowerCase();
    if (lower.contains('credit') || lower.contains('salary') || lower.contains('upi cr')) {
      return BankTransactionType.credit;
    }
    if (lower.contains('debit') || lower.contains('emi') || lower.contains('bill') || lower.contains('dr')) {
      return BankTransactionType.debit;
    }
    return BankTransactionType.unknown;
  }

  BankTransaction _tagTransaction(BankTransaction tx) {
    final lower = tx.description.toLowerCase();
    final tags = <String>{};

    if (_emiKeywords.any((keyword) => lower.contains(keyword))) {
      tags.add('EMI_DEBIT');
    }
    if (_utilityKeywords.any((keyword) => lower.contains(keyword))) {
      tags.add('UTILITY_DEBIT');
    }
    if (_insuranceKeywords.any((keyword) => lower.contains(keyword))) {
      tags.add('INSURANCE_DEBIT');
    }
    if (tx.type == BankTransactionType.credit) {
      tags.add('CREDIT');
    }
    if (tx.type == BankTransactionType.debit) {
      tags.add('DEBIT');
    }

    return BankTransaction(
      date: tx.date,
      description: tx.description,
      amount: tx.amount,
      type: tx.type,
      balance: tx.balance,
      tags: tags,
    );
  }

  EmiProfile _detectRecurringEmi(List<BankTransaction> transactions) {
    final emiTx = transactions
        .where((tx) => tx.tags.contains('EMI_DEBIT') && tx.type == BankTransactionType.debit)
        .toList(growable: false);

    final grouped = <String, List<BankTransaction>>{};
    for (final tx in emiTx) {
      final key = '${_normalizeDesc(tx.description)}|${tx.amount.toStringAsFixed(2)}';
      grouped.putIfAbsent(key, () => <BankTransaction>[]).add(tx);
    }

    var activeEmiCount = 0;
    var totalMonthlyEmi = 0.0;
    final lenders = <String>[];

    for (final entry in grouped.entries) {
      final items = [...entry.value]..sort((a, b) {
          final ad = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.compareTo(bd);
        });

      if (items.length < 2) {
        continue;
      }

      var recurringHits = 0;
      for (var i = 1; i < items.length; i++) {
        final prev = items[i - 1].date;
        final curr = items[i].date;
        if (prev == null || curr == null) {
          continue;
        }
        final diff = curr.difference(prev).inDays.abs();
        if (diff >= 28 && diff <= 35) {
          recurringHits += 1;
        }
      }

      if (recurringHits >= 1) {
        activeEmiCount += 1;
        totalMonthlyEmi += items.first.amount;
        lenders.add(_extractLender(items.first.description));
      }
    }

    return EmiProfile(
      activeEmiCount: activeEmiCount,
      totalMonthlyEmi: totalMonthlyEmi,
      detectedLenders: lenders,
    );
  }

  String _normalizeDesc(String description) {
    return description.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractLender(String description) {
    final tokens = description.split(RegExp(r'\s+'));
    if (tokens.isEmpty) {
      return 'Unknown';
    }
    return tokens.take(min(3, tokens.length)).join(' ').trim();
  }

  String _toCsv(List<BankTransaction> transactions) {
    final buffer = StringBuffer('transaction_date,transaction_description,transaction_amount,transaction_type,tags\n');
    for (final tx in transactions) {
      final date = tx.date == null
          ? ''
          : '${tx.date!.year.toString().padLeft(4, '0')}-${tx.date!.month.toString().padLeft(2, '0')}-${tx.date!.day.toString().padLeft(2, '0')}';
      final escapedDescription = tx.description.replaceAll('"', '""');
      final type = switch (tx.type) {
        BankTransactionType.credit => 'CREDIT',
        BankTransactionType.debit => 'DEBIT',
        BankTransactionType.unknown => 'UNKNOWN',
      };
      final tags = tx.tags.join('|');
      buffer.writeln('$date,"$escapedDescription",${tx.amount.toStringAsFixed(2)},$type,$tags');
    }
    return buffer.toString();
  }
}
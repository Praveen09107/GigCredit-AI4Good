import 'dart:convert';

import '../models/enums/document_type.dart';

class ParsedDocumentFields {
  const ParsedDocumentFields({
    required this.fields,
    required this.isValid,
    required this.missingCriticalFields,
  });

  final Map<String, String> fields;
  final bool isValid;
  final List<String> missingCriticalFields;
}

class FieldExtractors {
  static ParsedDocumentFields parse(DocumentType documentType, String text) {
    final cleaned = _normalize(text);
    switch (documentType) {
      case DocumentType.aadhaarFront:
      case DocumentType.aadhaarBack:
        return _parseAadhaar(cleaned);
      case DocumentType.pan:
        return _parsePan(cleaned);
      case DocumentType.bankStatement:
        return _parseBankStatement(cleaned);
      case DocumentType.electricityBill:
        return _parseElectricityBill(cleaned);
      case DocumentType.lpgBill:
        return _parseGasBill(cleaned);
      case DocumentType.mobileBill:
      case DocumentType.wifiBill:
        return _parseMobileBill(cleaned);
      case DocumentType.rc:
      case DocumentType.insurance:
      case DocumentType.governmentScheme:
      case DocumentType.itr:
        return const ParsedDocumentFields(
          fields: <String, String>{},
          isValid: false,
          missingCriticalFields: <String>['unsupported_document_type'],
        );
    }
  }

  static ParsedDocumentFields _parseAadhaar(String text) {
    final aadhaar = _extractAadhaarNumber(text);
    final dob = _extractFirst(text, [
      RegExp(r'\b\d{2}[\/-]\d{2}[\/-]\d{4}\b'),
      RegExp(r'\b\d{4}[\/-]\d{2}[\/-]\d{2}\b'),
    ]);
    final name = _extractLikelyName(text, deny: <String>{
      'government',
      'india',
      'uidai',
      'aadhaar',
      'dob',
      'male',
      'female',
      'address',
    });
    final address = _extractAfterKeyword(text, const ['address']);

    final fields = <String, String>{
      'name': name,
      'dob': dob,
      'aadhaar_number': aadhaar,
      'address': address,
    };
    final missing = _missing(fields, const ['name', 'aadhaar_number']);
    return ParsedDocumentFields(
      fields: fields,
      isValid: missing.isEmpty,
      missingCriticalFields: missing,
    );
  }

  static ParsedDocumentFields _parsePan(String text) {
    final pan = _extractPanNumber(text);
    final dob = _extractFirst(text, [RegExp(r'\b\d{2}[\/-]\d{2}[\/-]\d{4}\b')]);
    final name = _extractLikelyName(text, deny: <String>{
      'income',
      'tax',
      'department',
      'permanent',
      'account',
      'number',
      'father',
      'government',
      'india',
    });

    final fields = <String, String>{
      'name': name,
      'pan_number': pan,
      'dob': dob,
    };
    final missing = _missing(fields, const ['name', 'pan_number']);
    return ParsedDocumentFields(
      fields: fields,
      isValid: missing.isEmpty,
      missingCriticalFields: missing,
    );
  }

  static ParsedDocumentFields _parseBankStatement(String text) {
    final accountHolder = _extractFirst(text, [
      RegExp(r'(?:account\s*holder|customer\s*name|name)\s*[:\-]?\s*([A-Z][A-Z\s\.]{3,60})', caseSensitive: false),
    ], group: 1);
    final accountNumber = _extractFirst(text, [
      RegExp(r'axis\s*account\s*no\s*[:\-]?\s*([0-9Xx]{8,18})', caseSensitive: false),
      RegExp(r'(?:statement\s*of\s*[A-Za-z ]*account\s*no)\s*[:\-]?\s*([0-9Xx]{8,18})', caseSensitive: false),
      RegExp(r'(?:a\/c|account)\s*(?:no|number)?\s*[:\-]?\s*([0-9Xx]{8,18})', caseSensitive: false),
      RegExp(r'\b\d{9,18}\b'),
    ], group: 1);
    final ifsc = _extractFirst(text, [RegExp(r'\b[A-Z]{4}0[A-Z0-9]{6}\b')]);
    final bankName = _extractFirst(text, [
      RegExp(r'\b(hdfc bank|sbi|state bank of india|icici bank|axis bank|kotak|idfc first bank|union bank|canara bank|bank of baroda)\b', caseSensitive: false),
    ]);

    final tx = _extractTransactions(text);
    final fields = <String, String>{
      'name': accountHolder,
      'account_number': accountNumber,
      'ifsc': ifsc,
      'bank_name': bankName,
      'transactions_json': jsonEncode(tx),
      'transaction_count': tx.length.toString(),
    };
    final missing = _missing(fields, const ['account_number']);
    return ParsedDocumentFields(
      fields: fields,
      isValid: missing.isEmpty && tx.isNotEmpty,
      missingCriticalFields: missing,
    );
  }

  static ParsedDocumentFields _parseElectricityBill(String text) {
    final consumerNumber = _extractFirst(text, [
      RegExp(r'(?:s\.?\s*c\.?\s*number)\s*[:\-]?\s*([A-Z0-9\-]{5,20})', caseSensitive: false),
      RegExp(r'(?:consumer|service|rr)\s*(?:no|number|id)?\s*[:\-]?\s*([A-Z0-9\-]{6,20})', caseSensitive: false),
    ], group: 1);
    final amount = _extractFirst(text, [
      RegExp(r'(?:total)\s*[:\-]?\s*(?:rs\.?\s*)?([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:charges?)\s*[:\-]?\s*(?:rs\.?\s*)?([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
      RegExp(r'(?:total|net|amount)\s*(?:payable|due)?\s*[:\-]?\s*(?:rs\.?\s*)?([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ], group: 1);
    final billDate = _extractFirst(text, [
      RegExp(r'(?:date)\s*[:\-]?\s*(\d{2}[\/-]\d{2}[\/-]\d{4})', caseSensitive: false),
      RegExp(r'(?:bill\s*date)\s*[:\-]?\s*(\d{2}[\/-]\d{2}[\/-]\d{4})', caseSensitive: false),
    ], group: 1);
    final dueDate = _extractFirst(text, [RegExp(r'(?:due\s*date)\s*[:\-]?\s*(\d{2}[\/-]\d{2}[\/-]\d{4})', caseSensitive: false)], group: 1);

    final fields = <String, String>{
      'consumer_number': consumerNumber,
      'bill_amount': amount,
      'bill_date': billDate,
      'due_date': dueDate,
    };
    final missing = _missing(fields, const ['consumer_number', 'bill_amount']);
    return ParsedDocumentFields(
      fields: fields,
      isValid: missing.isEmpty,
      missingCriticalFields: missing,
    );
  }

  static ParsedDocumentFields _parseGasBill(String text) {
    final consumerId = _extractFirst(text, [
      RegExp(r'(?:consumer\s*no)\s*[:\-]?\s*([A-Z0-9\-]{4,20})', caseSensitive: false),
      RegExp(r'(?:consumer|customer|connection)\s*(?:id|no|number)?\s*[:\-]?\s*([A-Z0-9\-]{6,20})', caseSensitive: false),
    ], group: 1);
    final provider = _extractFirst(text, [
      RegExp(r'\b([A-Z][A-Z\s]{2,40}GAS\s+SERVICES?)\b', caseSensitive: false),
      RegExp(r'\b(indane|bharat gas|hp gas|io cl|hindustan petroleum|bharat petroleum)\b', caseSensitive: false),
    ]);
    final amount = _extractFirst(text, [
      RegExp(r'(?:final\s*price|amount\s*paid|amount|total|payable)\s*[:\-]?\s*(?:rs\.?\s*)?([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ], group: 1);
    final deliveryDate = _extractFirst(text, [
      RegExp(r'(?:order\s*date|tax\s*invoice\s*date|delivery|invoice|bill)\s*date\s*[:\-]?\s*(\d{2}[\/-]\d{2}[\/-]\d{4})', caseSensitive: false),
      RegExp(r'(?:delivery|invoice|bill)\s*date\s*[:\-]?\s*(\d{2}[\/-]\d{2}[\/-]\d{4})', caseSensitive: false),
    ], group: 1);

    final fields = <String, String>{
      'consumer_id': consumerId,
      'provider': provider,
      'amount': amount,
      'delivery_date': deliveryDate,
    };
    final missing = _missing(fields, const ['consumer_id', 'amount']);
    return ParsedDocumentFields(
      fields: fields,
      isValid: missing.isEmpty,
      missingCriticalFields: missing,
    );
  }

  static ParsedDocumentFields _parseMobileBill(String text) {
    final mobile = _extractFirst(text, [RegExp(r'\b(?:\+91[-\s]?)?[6-9]\d{9}\b')])
        .replaceAll(RegExp(r'\D'), '');
    final provider = _extractFirst(text, [
      RegExp(r'\b(jio|airtel|vodafone|vi\b|bsnl)\b', caseSensitive: false),
    ]);
    final amount = _extractFirst(text, [
      RegExp(r'(?:total|amount|due|payable)\s*[:\-]?\s*(?:rs\.?\s*)?([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ], group: 1);
    final billingCycle = _extractFirst(text, [
      RegExp(r'(?:bill\s*period|billing\s*cycle)\s*[:\-]?\s*([A-Za-z0-9\-/ ]{4,30})', caseSensitive: false),
    ], group: 1);

    final fields = <String, String>{
      'mobile_number': mobile,
      'provider': provider,
      'amount': amount,
      'billing_cycle': billingCycle,
    };
    final missing = _missing(fields, const ['mobile_number', 'amount']);
    return ParsedDocumentFields(
      fields: fields,
      isValid: missing.isEmpty,
      missingCriticalFields: missing,
    );
  }

  static String _normalize(String text) {
    return text
        .replaceAll('\u0000', ' ')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ')
        .replaceAll(RegExp(r'\r'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
  }

  static String _extractFirst(
    String text,
    List<RegExp> patterns, {
    int group = 0,
  }) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) {
        continue;
      }
      String value = '';
      if (group > 0) {
        try {
          value = match.group(group) ?? '';
        } on RangeError {
          value = match.group(0) ?? '';
        }
      } else {
        value = match.group(0) ?? '';
      }
      final cleaned = value.trim();
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
    return '';
  }

  static String _extractAadhaarNumber(String text) {
    final direct = _extractFirst(text, [
      RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b'),
      RegExp(r'\b\d{12}\b'),
    ]).replaceAll(RegExp(r'\D'), '');
    if (direct.length == 12) {
      return direct;
    }

    // OCR frequently confuses O/0 and I/1 in number-heavy regions.
    final normalized = text
        .toUpperCase()
        .replaceAll('O', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('S', '5')
        .replaceAll(RegExp(r'[^0-9]'), ' ');

    final candidate = _extractFirst(normalized, [
      RegExp(r'\b\d{4}\s+\d{4}\s+\d{4}\b'),
      RegExp(r'\b\d{12}\b'),
    ]).replaceAll(RegExp(r'\D'), '');
    return candidate.length == 12 ? candidate : '';
  }

  static String _extractPanNumber(String text) {
    final upper = text.toUpperCase();
    final direct = _extractFirst(upper, [RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b')]);
    if (direct.isNotEmpty) {
      return direct;
    }

    final cleaned = upper
        .replaceAll(RegExp(r'[^A-Z0-9\n ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final token in cleaned.split(' ')) {
      if (token.length != 10) {
        continue;
      }
      final repaired = token
          .replaceAll('0', 'O')
          .replaceAll('1', 'I')
          .replaceAll('5', 'S');
      final candidate = '${repaired.substring(0, 5)}${token.substring(5, 9).replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1').replaceAll('S', '5')}${repaired.substring(9)}';
      if (RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(candidate)) {
        return candidate;
      }
    }

    return '';
  }

  static String _extractLikelyName(String text, {required Set<String> deny}) {
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final candidate = line.trim();
      if (candidate.length < 4 || candidate.length > 50) {
        continue;
      }
      if (RegExp(r'\d').hasMatch(candidate)) {
        continue;
      }
      final lower = candidate.toLowerCase();
      if (deny.any(lower.contains)) {
        continue;
      }
      final words = candidate.split(' ').where((w) => w.isNotEmpty).toList(growable: false);
      if (words.length >= 2 && words.length <= 4) {
        return words.map((w) => _titleCaseWord(w)).join(' ');
      }
    }
    return '';
  }

  static String _extractAfterKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      final match = RegExp('$keyword\\s*[:\\-]?\\s*(.{8,120})', caseSensitive: false)
          .firstMatch(text);
      if (match != null) {
        return (match.group(1) ?? '').trim();
      }
    }
    return '';
  }

  static String _titleCaseWord(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  static List<String> _missing(Map<String, String> fields, List<String> requiredKeys) {
    final out = <String>[];
    for (final key in requiredKeys) {
      if ((fields[key] ?? '').trim().isEmpty) {
        out.add(key);
      }
    }
    return out;
  }

  static List<Map<String, String>> _extractTransactions(String text) {
    final out = <Map<String, String>>[];
    final dedupe = <String>{};
    final detailedRowPattern = RegExp(
      r'(\d{2}[\/-]\d{2}[\/-]\d{2,4})\s+(.{3,90}?)\s+([0-9,]+(?:\.\d{1,2})?)\s+([0-9,]+(?:\.\d{1,2})?)?(?:\s+([0-9,]+(?:\.\d{1,2})?))?',
      caseSensitive: false,
    );

    for (final match in detailedRowPattern.allMatches(text)) {
      final date = (match.group(1) ?? '').trim();
      final narration = (match.group(2) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final debit = (match.group(3) ?? '').trim();
      final credit = (match.group(4) ?? '').trim();
      final balance = (match.group(5) ?? '').trim();
      if (date.isEmpty || narration.isEmpty || debit.isEmpty) {
        continue;
      }
      final key = '$date|$debit|$narration';
      if (dedupe.contains(key)) {
        continue;
      }
      dedupe.add(key);
      out.add(<String, String>{
        'date': date,
        'description': narration,
        'debit': debit,
        'credit': credit,
        'balance': balance,
      });
    }

    if (out.isNotEmpty) {
      return out;
    }

    final compactAxisLikePattern = RegExp(
      r'(\d{2}[\/-]\d{2}[\/-]\d{4})\s+(.{3,120}?)\s+([0-9,]+(?:\.\d{1,2})?)\s+([0-9,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );

    double? previousBalance;
    for (final match in compactAxisLikePattern.allMatches(text)) {
      final date = (match.group(1) ?? '').trim();
      final narration = (match.group(2) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      final amount = (match.group(3) ?? '').trim();
      final balance = (match.group(4) ?? '').trim();
      if (date.isEmpty || narration.isEmpty || amount.isEmpty || balance.isEmpty) {
        continue;
      }

      final key = '$date|$amount|$narration';
      if (!dedupe.add(key)) {
        continue;
      }

      final amountValue = double.tryParse(amount.replaceAll(',', ''));
      final balanceValue = double.tryParse(balance.replaceAll(',', ''));
      var debit = amount;
      var credit = '';
      if (amountValue != null && balanceValue != null && previousBalance != null) {
        if (balanceValue > previousBalance! + 0.009) {
          credit = amount;
          debit = '';
        }
      }

      out.add(<String, String>{
        'date': date,
        'description': narration,
        'debit': debit,
        'credit': credit,
        'balance': balance,
      });

      previousBalance = balanceValue ?? previousBalance;
    }

    return out;
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/field_extractors.dart';
import 'package:gigcredit_app/core/bank/bank_statement_parser.dart';
import 'package:gigcredit_app/models/enums/document_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sample Inputs OCR Parsing', () {
    test('parses sample Axis statement extracted text with production parser', () async {
      final workspaceRoot = Directory.current.parent.path;
      final statementPath =
          '$workspaceRoot${Platform.pathSeparator}sample inputs${Platform.pathSeparator}Bank Statement.extracted.txt';
      final file = File(statementPath);

      expect(await file.exists(), isTrue, reason: 'Sample bank statement text file missing.');

      final rawText = await file.readAsString();
      final parser = BankStatementParser();
      final parsed = parser.parseText(rawText: rawText, bankName: 'Axis Bank');

      expect(parsed.supported, isTrue);
      expect(parsed.accountNumber, isNotEmpty);
      expect(parsed.ifscCode, isNotEmpty);
      expect(parsed.transactionCount, greaterThan(50));
      expect(parsed.toDate.isAfter(parsed.fromDate), isTrue);
    });

    test('extracts core bank fields from sample extracted text', () async {
      final workspaceRoot = Directory.current.parent.path;
      final statementPath =
          '$workspaceRoot${Platform.pathSeparator}sample inputs${Platform.pathSeparator}Bank Statement.extracted.txt';
      final file = File(statementPath);
      expect(await file.exists(), isTrue, reason: 'Sample bank statement text file missing.');

      final rawText = await file.readAsString();
      final result = FieldExtractors.parse(DocumentType.bankStatement, rawText);

      expect(result.fields['account_number'], isNotEmpty);
      expect(result.fields['ifsc'], isNotEmpty);
      expect(int.tryParse(result.fields['transaction_count'] ?? '0') ?? 0, greaterThan(20));
    });

    test('extracts PAN from OCR-noisy text variant', () {
      const noisyPanText = 'Permanent Account Number: 1PZPP3254R';
      final result = FieldExtractors.parse(DocumentType.pan, noisyPanText);
      expect(result.fields['pan_number'], 'IPZPP3254R');
    });

    test('extracts Aadhaar from OCR-noisy text variant', () {
      const noisyAadhaarText = 'Aadhaar No: 7494 2OO6 799O';
      final result = FieldExtractors.parse(DocumentType.aadhaarFront, noisyAadhaarText);
      expect(result.fields['aadhaar_number'], '749420067990');
    });
  });
}

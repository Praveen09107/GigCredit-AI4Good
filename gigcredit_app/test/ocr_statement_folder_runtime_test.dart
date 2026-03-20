import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/services/ondevice_ocr_service.dart';

String _extractFirst(RegExp pattern, String input) {
  final match = pattern.firstMatch(input);
  if (match == null) {
    return 'NOT_FOUND';
  }
  return match.group(0) ?? 'NOT_FOUND';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OCR over statement folder and print results', () async {
    final service = OnDeviceOcrService(requireProductionReadiness: false);
    final root = Directory.current.parent.path;
    final statementDir = Directory('$root${Platform.pathSeparator}statement');

    expect(await statementDir.exists(), isTrue,
        reason: 'Expected statement directory at ${statementDir.path}');

    final files = await statementDir
        .list(recursive: true)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) {
      final p = file.path.toLowerCase();
      return p.endsWith('.pdf') || p.endsWith('.png') || p.endsWith('.jpg') || p.endsWith('.jpeg');
    }).toList();

    expect(files.isNotEmpty, isTrue, reason: 'No statement/bill files found to OCR.');

    for (final file in files) {
      final result = await service.extractFromFile(filePath: file.path);
      final text = result.rawText;

      final date = _extractFirst(RegExp(r'\b\d{2}[/-]\d{2}[/-]\d{2,4}\b'), text);
      final amount = _extractFirst(RegExp(r'\b(?:INR|Rs\.?|₹)?\s?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\b', caseSensitive: false), text);
      final txnType = _extractFirst(RegExp(r'\b(CR|DR|DEBIT|CREDIT|WITHDRAWAL|UPI|NEFT|IMPS)\b', caseSensitive: false), text);
      final balance = _extractFirst(RegExp(r'\b(?:BAL|BALANCE)\s*[:\-]?\s*(?:INR|Rs\.?|₹)?\s?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\b', caseSensitive: false), text);
      final consumerNo = _extractFirst(RegExp(r'\b(?:consumer|service|account)\s*(?:no|number|id)?\s*[:\-]?\s*[A-Z0-9]{6,}\b', caseSensitive: false), text);

      print('----- OCR FILE START -----');
      print('FILE: ${file.path}');
      print('SOURCE: ${result.source}');
      print('CONFIDENCE: ${result.confidence.toStringAsFixed(3)}');
      print('DATE: $date');
      print('AMOUNT: $amount');
      print('TXN_TYPE: $txnType');
      print('BALANCE: $balance');
      print('CONSUMER_OR_SERVICE_NO: $consumerNo');
      print('RAW_TEXT_PREVIEW: ${text.length > 1200 ? text.substring(0, 1200) : text}');
      print('----- OCR FILE END -----');
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/native_document_processor.dart';
import 'package:gigcredit_app/models/enums/document_type.dart';

Future<List<int>> _loadAnyStatementBytes() async {
  final root = Directory.current.parent.path;
  final statementDir = Directory('$root${Platform.pathSeparator}statement');
  final files = await statementDir
      .list(recursive: true)
      .where((entity) => entity is File)
      .cast<File>()
      .where((file) => file.path.toLowerCase().endsWith('.pdf'))
      .toList();

  if (files.isEmpty) {
    throw StateError('No statement PDF found for runtime audit.');
  }

  return files.first.readAsBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Document processor runtime audit prints extraction/authenticity metadata', () async {
    final bytes = await _loadAnyStatementBytes();
    final processor = NativeDocumentProcessor.withDefaults();

    final bankDoc = await processor.process(
      documentType: DocumentType.bankStatement,
      imageBytes: bytes,
    );
    final panDoc = await processor.process(
      documentType: DocumentType.pan,
      imageBytes: bytes,
    );
    final aadhaarDoc = await processor.process(
      documentType: DocumentType.aadhaarFront,
      imageBytes: bytes,
    );

    print('----- DOCUMENT PROCESSOR AUDIT START -----');
    print('BANK authenticity: ${bankDoc.authenticity.label.name} ${bankDoc.authenticity.confidence}');
    print('BANK ocr confidence: ${bankDoc.ocr.confidence}');
    print('BANK extracted fields: ${bankDoc.fields}');
    print('BANK metadata: ${bankDoc.metadata}');

    print('PAN authenticity: ${panDoc.authenticity.label.name} ${panDoc.authenticity.confidence}');
    print('PAN ocr confidence: ${panDoc.ocr.confidence}');
    print('PAN extracted fields: ${panDoc.fields}');

    print('AADHAAR authenticity: ${aadhaarDoc.authenticity.label.name} ${aadhaarDoc.authenticity.confidence}');
    print('AADHAAR ocr confidence: ${aadhaarDoc.ocr.confidence}');
    print('AADHAAR extracted fields: ${aadhaarDoc.fields}');
    print('----- DOCUMENT PROCESSOR AUDIT END -----');

    expect(bankDoc.metadata.containsKey('native_runtime_ready'), isTrue);
  });
}

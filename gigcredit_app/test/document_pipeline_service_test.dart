import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/ai_interfaces.dart';
import 'package:gigcredit_app/ai/ocr_engine.dart';
import 'package:gigcredit_app/models/enums/document_type.dart';
import 'package:gigcredit_app/services/document_pipeline_service.dart';
import 'package:gigcredit_app/ai/verification_validation_engine.dart';

class _FakeDocumentProcessor implements DocumentProcessor {
  const _FakeDocumentProcessor(this.result);

  final ProcessedDocument result;

  @override
  Future<ProcessedDocument> process({
    required DocumentType documentType,
    required List<int> imageBytes,
  }) async {
    return result;
  }
}

class _FakeRoutingProcessor implements DocumentProcessor {
  const _FakeRoutingProcessor({required this.results});

  final Map<DocumentType, ProcessedDocument> results;

  @override
  Future<ProcessedDocument> process({
    required DocumentType documentType,
    required List<int> imageBytes,
  }) async {
    return results[documentType] ??
        ProcessedDocument(
          documentType: documentType,
          ocr: const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true),
          authenticity: const AuthenticityResult(
            label: AuthenticityLabel.suspicious,
            confidence: 0.0,
          ),
          fields: const <String, String>{},
          validation: const ValidationSummary(
            passed: false,
            issues: <ValidationIssue>[],
          ),
        );
  }
}

Future<String> _writeTempFile(List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('gigcredit_pipeline_test_');
  final file = File('${dir.path}${Platform.pathSeparator}doc.pdf');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

void main() {
  group('DocumentPipelineService', () {
    test('rejects password-protected PDF marker result explicitly', () async {
      const fakeResult = ProcessedDocument(
        documentType: DocumentType.bankStatement,
        ocr: OcrResult(
          rawText: kPasswordProtectedPdfMarker,
          confidence: 0.0,
          lowConfidence: true,
        ),
        authenticity: AuthenticityResult(
          label: AuthenticityLabel.real,
          confidence: 0.95,
        ),
        fields: <String, String>{},
      );

      final service = DocumentPipelineService(
        processorFuture: Future<DocumentProcessor>.value(
          const _FakeDocumentProcessor(fakeResult),
        ),
      );

      final filePath = await _writeTempFile('%PDF-1.4\n/Encrypt 1 0 R\n'.codeUnits);

      expect(
        () => service.processFile(
          filePath: filePath,
          documentType: DocumentType.bankStatement,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Password-protected PDF detected'),
          ),
        ),
      );
    });

    test('auto-detect selects strongest utility candidate result', () async {
      const processor = _FakeRoutingProcessor(
        results: <DocumentType, ProcessedDocument>{
          DocumentType.mobileBill: ProcessedDocument(
            documentType: DocumentType.mobileBill,
            ocr: OcrResult(rawText: 'weak text', confidence: 0.25, lowConfidence: true),
            authenticity: AuthenticityResult(
              label: AuthenticityLabel.real,
              confidence: 0.90,
            ),
            fields: <String, String>{'mobile_number': ''},
            validation: ValidationSummary(
              passed: false,
              issues: <ValidationIssue>[],
            ),
          ),
          DocumentType.electricityBill: ProcessedDocument(
            documentType: DocumentType.electricityBill,
            ocr: OcrResult(rawText: 'tangedco receipt text', confidence: 0.91),
            authenticity: AuthenticityResult(
              label: AuthenticityLabel.real,
              confidence: 0.95,
            ),
            fields: <String, String>{
              'bill_id': 'EB-0119400742',
              'consumer_number': '0119400742',
              'amount': '905.00',
              'ocr_summary': 'tangedco receipt amount 905.00 paid',
            },
            validation: ValidationSummary(
              passed: true,
              issues: <ValidationIssue>[],
            ),
          ),
        },
      );

      final service = DocumentPipelineService(
        processorFuture: Future<DocumentProcessor>.value(processor),
      );
      final filePath = await _writeTempFile('%PDF-1.4 test'.codeUnits);

      final detected = await service.processFile(
        filePath: filePath,
        autoDetectCandidates: const <DocumentType>[
          DocumentType.mobileBill,
          DocumentType.electricityBill,
        ],
      );

      expect(detected.documentType, DocumentType.electricityBill);
      expect(detected.fields['consumer_number'], '0119400742');
    });

    test('rejects OCR result with insufficient text signal', () async {
      const fakeResult = ProcessedDocument(
        documentType: DocumentType.pan,
        ocr: OcrResult(
          rawText: '---',
          confidence: 0.98,
          lowConfidence: false,
        ),
        authenticity: AuthenticityResult(
          label: AuthenticityLabel.real,
          confidence: 0.99,
        ),
        fields: <String, String>{
          'pan_number': 'ABCDE1234F',
        },
      );

      final service = DocumentPipelineService(
        processorFuture: Future<DocumentProcessor>.value(
          const _FakeDocumentProcessor(fakeResult),
        ),
      );
      final filePath = await _writeTempFile('%PDF-1.4 test'.codeUnits);

      expect(
        () => service.processFile(
          filePath: filePath,
          documentType: DocumentType.pan,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('OCR text is insufficient'),
          ),
        ),
      );
    });

    test('enriches missing PAN using context when OCR contains user-entered PAN token', () async {
      const fakeResult = ProcessedDocument(
        documentType: DocumentType.pan,
        ocr: OcrResult(
          rawText: 'Permanent Account Number ABCDE1234F holder details',
          confidence: 0.91,
          lowConfidence: false,
        ),
        authenticity: AuthenticityResult(
          label: AuthenticityLabel.real,
          confidence: 0.98,
        ),
        fields: <String, String>{
          'pan_number': 'UNKNOWN',
        },
      );

      final service = DocumentPipelineService(
        processorFuture: Future<DocumentProcessor>.value(
          const _FakeDocumentProcessor(fakeResult),
        ),
      );
      final filePath = await _writeTempFile('%PDF-1.4 test with PAN'.codeUnits);

      final result = await service.processFile(
        filePath: filePath,
        documentType: DocumentType.pan,
        validationContext: const ValidationContext(
          apiVerifiedFields: <String, String>{
            'pan_number': 'ABCDE1234F',
          },
        ),
      );

      expect(result.fields['pan_number'], 'ABCDE1234F');
      expect(result.validation.passed, isTrue);
    });

    test('enriches missing ITR ack from context only when OCR carries matching token', () async {
      const fakeResult = ProcessedDocument(
        documentType: DocumentType.itr,
        ocr: OcrResult(
          rawText: 'ITR ACKNOWLEDGEMENT A1B2C3D4 annual income 720000',
          confidence: 0.89,
          lowConfidence: false,
        ),
        authenticity: AuthenticityResult(
          label: AuthenticityLabel.real,
          confidence: 0.94,
        ),
        fields: <String, String>{
          'itr_ack_number': 'UNKNOWN',
          'annual_income': '720000',
          'monthly_income': '60000',
        },
      );

      final service = DocumentPipelineService(
        processorFuture: Future<DocumentProcessor>.value(
          const _FakeDocumentProcessor(fakeResult),
        ),
      );
      final filePath = await _writeTempFile('%PDF-1.4 test with ITR'.codeUnits);

      final result = await service.processFile(
        filePath: filePath,
        documentType: DocumentType.itr,
        validationContext: const ValidationContext(
          apiVerifiedFields: <String, String>{
            'itr_ack_number': 'A1B2C3D4',
          },
        ),
      );

      expect(result.fields['itr_ack_number'], 'A1B2C3D4');
    });

    test('fails validation when step contract required field is missing', () async {
      const fakeResult = ProcessedDocument(
        documentType: DocumentType.governmentScheme,
        ocr: OcrResult(
          rawText: 'scheme certificate without reference id text present',
          confidence: 0.88,
          lowConfidence: false,
        ),
        authenticity: AuthenticityResult(
          label: AuthenticityLabel.real,
          confidence: 0.91,
        ),
        fields: <String, String>{
          'scheme_reference': 'UNKNOWN',
        },
      );

      final service = DocumentPipelineService(
        processorFuture: Future<DocumentProcessor>.value(
          const _FakeDocumentProcessor(fakeResult),
        ),
      );
      final filePath = await _writeTempFile('%PDF-1.4 scheme contract'.codeUnits);

      expect(
        () => service.processFile(
          filePath: filePath,
          documentType: DocumentType.governmentScheme,
          validationContext: const ValidationContext(
            stepTag: 'step6_svanidhi',
            requiredFields: <String>['scheme_reference'],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Document validation failed'),
          ),
        ),
      );
    });
  });
}

import '../models/enums/document_type.dart';
import 'ai_interfaces.dart';

class MockDocumentProcessor implements DocumentProcessor {
  const MockDocumentProcessor();

  @override
  Future<ProcessedDocument> process({
    required DocumentType documentType,
    required List<int> imageBytes,
  }) async {
    final ocr = OcrResult(
      rawText: _sampleRawText(documentType),
      confidence: 0.96,
    );
    final authenticity = AuthenticityResult(
      label: AuthenticityLabel.real,
      confidence: 0.94,
    );

    return ProcessedDocument(
      documentType: documentType,
      ocr: ocr,
      authenticity: authenticity,
      fields: _sampleFields(documentType),
    );
  }

  String _sampleRawText(DocumentType type) {
    switch (type) {
      case DocumentType.aadhaarFront:
        return 'Name: RAVI KUMAR\nDOB: 14/07/1997\nAadhaar: XXXX XXXX 4123';
      case DocumentType.aadhaarBack:
        return 'Address: Bengaluru, Karnataka';
      case DocumentType.pan:
        return 'PAN: ABCDE1234F\nName: RAVI KUMAR';
      case DocumentType.bankStatement:
        return 'Statement Period: 01-09-2025 to 28-02-2026';
      case DocumentType.electricityBill:
        return 'Bill Amount: 1450\nConsumer No: 9988776655';
      case DocumentType.lpgBill:
        return 'Distributor: Bharat Gas\nAmount: 920';
      case DocumentType.mobileBill:
        return 'Mobile: 9876543210\nAmount: 399';
      case DocumentType.wifiBill:
        return 'Provider: JioFiber\nAmount: 999';
      case DocumentType.rc:
        return 'Vehicle No: KA01AB1234';
      case DocumentType.insurance:
        return 'Policy No: POL12345678';
      case DocumentType.itr:
        return 'ITR Ack No: ITR2026ABC123';
    }
  }

  Map<String, String> _sampleFields(DocumentType type) {
    switch (type) {
      case DocumentType.aadhaarFront:
        return {
          'full_name': 'RAVI KUMAR',
          'dob': '1997-07-14',
          'aadhaar_last4': '4123',
        };
      case DocumentType.aadhaarBack:
        return {
          'state': 'Karnataka',
          'city': 'Bengaluru',
        };
      case DocumentType.pan:
        return {
          'pan_number': 'ABCDE1234F',
          'full_name': 'RAVI KUMAR',
        };
      case DocumentType.bankStatement:
        return {
          'period_start': '2025-09-01',
          'period_end': '2026-02-28',
        };
      case DocumentType.electricityBill:
        return {
          'amount': '1450',
          'consumer_number': '9988776655',
        };
      case DocumentType.lpgBill:
        return {
          'amount': '920',
          'provider': 'Bharat Gas',
        };
      case DocumentType.mobileBill:
        return {
          'amount': '399',
          'mobile': '9876543210',
        };
      case DocumentType.wifiBill:
        return {
          'amount': '999',
          'provider': 'JioFiber',
        };
      case DocumentType.rc:
        return {
          'vehicle_number': 'KA01AB1234',
        };
      case DocumentType.insurance:
        return {
          'policy_number': 'POL12345678',
          'status': 'ACTIVE',
        };
      case DocumentType.itr:
        return {
          'itr_ack_number': 'ITR2026ABC123',
          'assessment_year': '2025-26',
        };
    }
  }
}

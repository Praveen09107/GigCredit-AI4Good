import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/verification_validation_engine.dart';
import 'package:gigcredit_app/models/enums/document_type.dart';

void main() {
  group('VerificationValidationEngine cross-domain checks', () {
    const engine = VerificationValidationEngine();

    test('flags PAN name mismatch with profile', () {
      const context = ValidationContext(
        profile: VerifiedProfileSnapshot(
          fullName: 'Ravi Kumar',
          panNumber: 'ABCDE1234F',
        ),
      );

      final result = engine.run(
        documentType: DocumentType.pan,
        extractedFields: const {
          'pan_number': 'ABCDE1234F',
          'full_name': 'Suresh Kumar',
        },
        context: context,
      );

      expect(result.passed, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'PAN_NAME_PROFILE_MISMATCH'),
        isTrue,
      );
    });

    test('flags bank IFSC mismatch with profile/api', () {
      const context = ValidationContext(
        profile: VerifiedProfileSnapshot(
          bankIfsc: 'SBIN0000001',
          bankAccountHolder: 'Ravi Kumar',
        ),
        apiVerifiedFields: {
          'ifsc_code': 'HDFC0001234',
        },
      );

      final result = engine.run(
        documentType: DocumentType.bankStatement,
        extractedFields: const {
          'statement_id': 'BS-1234',
          'ifsc_code': 'ICIC0005555',
          'account_holder_name': 'Ravi Kumar',
          'ocr_summary': 'sample bank statement text',
        },
        context: context,
      );

      expect(result.passed, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'BANK_IFSC_PROFILE_MISMATCH'),
        isTrue,
      );
      expect(
        result.issues.any((issue) => issue.code == 'BANK_IFSC_API_MISMATCH'),
        isTrue,
      );
    });

    test('flags ITR declared income mismatch against profile', () {
      const context = ValidationContext(
        profile: VerifiedProfileSnapshot(
          selfDeclaredMonthlyIncome: 10000,
        ),
      );

      final result = engine.run(
        documentType: DocumentType.itr,
        extractedFields: const {
          'itr_ack_number': 'ITR123',
          'annual_income': '480000',
          'monthly_income': '40000',
          'ocr_summary': 'sample itr text',
        },
        context: context,
      );

      expect(result.passed, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'ITR_DECLARED_INCOME_MISMATCH'),
        isTrue,
      );
    });

    test('flags bank IFSC format violations in individual validation', () {
      final result = engine.run(
        documentType: DocumentType.bankStatement,
        extractedFields: const {
          'statement_id': 'BS-1002',
          'ifsc_code': 'BAD123',
          'account_holder_name': 'Ravi Kumar',
          'ocr_summary': 'sample statement text with sufficient content',
        },
      );

      expect(result.passed, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'BANK_IFSC_FORMAT_INVALID'),
        isTrue,
      );
    });

    test('treats placeholder scheme reference as missing', () {
      final result = engine.run(
        documentType: DocumentType.governmentScheme,
        extractedFields: const {
          'scheme_reference': 'UNKNOWN',
        },
      );

      expect(result.passed, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'SCHEME_REFERENCE_MISSING'),
        isTrue,
      );
    });
  });
}

import '../models/enums/document_type.dart';
import 'ai_interfaces.dart';

class VerifiedProfileSnapshot {
  const VerifiedProfileSnapshot({
    this.fullName,
    this.panNumber,
    this.aadhaarLast4,
    this.bankAccountHolder,
    this.bankIfsc,
  });

  final String? fullName;
  final String? panNumber;
  final String? aadhaarLast4;
  final String? bankAccountHolder;
  final String? bankIfsc;
}

class ValidationContext {
  const ValidationContext({
    this.profile,
    this.apiVerifiedFields = const <String, String>{},
  });

  final VerifiedProfileSnapshot? profile;
  final Map<String, String> apiVerifiedFields;
}

class VerificationValidationEngine {
  const VerificationValidationEngine();

  ValidationSummary run({
    required DocumentType documentType,
    required Map<String, String> extractedFields,
    ValidationContext context = const ValidationContext(),
  }) {
    final issues = <ValidationIssue>[];

    _runIndividualValidation(documentType, extractedFields, issues);
    _runCrossInternalValidation(documentType, extractedFields, issues);
    _runCrossStepValidation(documentType, extractedFields, context, issues);

    return ValidationSummary(
      passed: issues.isEmpty,
      issues: issues,
    );
  }

  void _runIndividualValidation(
    DocumentType type,
    Map<String, String> fields,
    List<ValidationIssue> issues,
  ) {
    switch (type) {
      case DocumentType.pan:
        _requireRegex(
          fields,
          field: 'pan_number',
          regex: RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$'),
          issues: issues,
          code: 'PAN_FORMAT_INVALID',
          message: 'PAN number failed individual format validation.',
        );
      case DocumentType.aadhaarFront:
        _requireRegex(
          fields,
          field: 'aadhaar_last4',
          regex: RegExp(r'^[0-9]{4}$'),
          issues: issues,
          code: 'AADHAAR_LAST4_INVALID',
          message: 'Aadhaar last4 failed individual format validation.',
        );
      case DocumentType.bankStatement:
        _requireField(
          fields,
          field: 'statement_id',
          issues: issues,
          code: 'STATEMENT_ID_MISSING',
          message: 'Statement identifier missing from extracted fields.',
        );
      case DocumentType.electricityBill:
      case DocumentType.lpgBill:
      case DocumentType.mobileBill:
      case DocumentType.wifiBill:
        _requirePositiveNumber(
          fields,
          field: 'amount',
          issues: issues,
          code: 'BILL_AMOUNT_INVALID',
          message: 'Bill amount must be a positive numeric value.',
        );
      case DocumentType.insurance:
        _requireField(
          fields,
          field: 'policy_number',
          issues: issues,
          code: 'POLICY_NUMBER_MISSING',
          message: 'Policy number is required for insurance validation.',
        );
      case DocumentType.itr:
        _requireField(
          fields,
          field: 'itr_ack_number',
          issues: issues,
          code: 'ITR_ACK_MISSING',
          message: 'ITR acknowledgement number is required.',
        );
      case DocumentType.rc:
      case DocumentType.aadhaarBack:
        break;
    }
  }

  void _runCrossInternalValidation(
    DocumentType type,
    Map<String, String> fields,
    List<ValidationIssue> issues,
  ) {
    if (type == DocumentType.bankStatement) {
      final summary = fields['ocr_summary']?.trim() ?? '';
      if (summary.isEmpty) {
        issues.add(
          const ValidationIssue(
            layer: ValidationLayer.crossInternal,
            code: 'BANK_SUMMARY_EMPTY',
            message: 'Bank statement OCR summary is empty.',
            field: 'ocr_summary',
          ),
        );
      }
    }

    if (
        type == DocumentType.electricityBill ||
        type == DocumentType.lpgBill ||
        type == DocumentType.mobileBill ||
        type == DocumentType.wifiBill) {
      final amount = fields['amount']?.trim();
      final summary = fields['ocr_summary']?.toLowerCase() ?? '';
      if (amount != null && amount.isNotEmpty && !summary.contains(amount)) {
        issues.add(
          ValidationIssue(
            layer: ValidationLayer.crossInternal,
            code: 'BILL_AMOUNT_OCR_MISMATCH',
            message: 'Bill amount does not match OCR summary text.',
            field: 'amount',
          ),
        );
      }
    }
  }

  void _runCrossStepValidation(
    DocumentType type,
    Map<String, String> fields,
    ValidationContext context,
    List<ValidationIssue> issues,
  ) {
    final profile = context.profile;

    if (profile != null && type == DocumentType.pan) {
      final extractedPan = fields['pan_number']?.trim().toUpperCase();
      final profilePan = profile.panNumber?.trim().toUpperCase();
      if (
          extractedPan != null &&
          extractedPan.isNotEmpty &&
          profilePan != null &&
          profilePan.isNotEmpty &&
          extractedPan != profilePan) {
        issues.add(
          const ValidationIssue(
            layer: ValidationLayer.crossStep,
            code: 'PAN_CROSS_STEP_MISMATCH',
            message: 'PAN mismatch with previously verified profile.',
            field: 'pan_number',
          ),
        );
      }
    }

    if (profile != null && type == DocumentType.aadhaarFront) {
      final extractedLast4 = fields['aadhaar_last4']?.trim();
      final profileLast4 = profile.aadhaarLast4?.trim();
      if (
          extractedLast4 != null &&
          extractedLast4.isNotEmpty &&
          profileLast4 != null &&
          profileLast4.isNotEmpty &&
          extractedLast4 != profileLast4) {
        issues.add(
          const ValidationIssue(
            layer: ValidationLayer.crossStep,
            code: 'AADHAAR_CROSS_STEP_MISMATCH',
            message: 'Aadhaar last4 mismatch with previously verified profile.',
            field: 'aadhaar_last4',
          ),
        );
      }
    }

    if (type == DocumentType.pan) {
      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'pan_number',
        issues: issues,
        code: 'PAN_API_MISMATCH',
        message: 'PAN mismatch against backend verification response.',
      );
    }
    if (type == DocumentType.insurance) {
      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'policy_number',
        issues: issues,
        code: 'POLICY_API_MISMATCH',
        message: 'Policy number mismatch against backend verification response.',
      );
    }
  }

  void _requireField(
    Map<String, String> fields, {
    required String field,
    required List<ValidationIssue> issues,
    required String code,
    required String message,
  }) {
    final value = fields[field]?.trim();
    if (value == null || value.isEmpty) {
      issues.add(
        ValidationIssue(
          layer: ValidationLayer.individual,
          code: code,
          message: message,
          field: field,
        ),
      );
    }
  }

  void _requireRegex(
    Map<String, String> fields, {
    required String field,
    required RegExp regex,
    required List<ValidationIssue> issues,
    required String code,
    required String message,
  }) {
    final value = fields[field]?.trim();
    if (value == null || value.isEmpty || !regex.hasMatch(value.toUpperCase())) {
      issues.add(
        ValidationIssue(
          layer: ValidationLayer.individual,
          code: code,
          message: message,
          field: field,
        ),
      );
    }
  }

  void _requirePositiveNumber(
    Map<String, String> fields, {
    required String field,
    required List<ValidationIssue> issues,
    required String code,
    required String message,
  }) {
    final value = fields[field]?.replaceAll(',', '').trim();
    final parsed = value == null ? null : double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      issues.add(
        ValidationIssue(
          layer: ValidationLayer.individual,
          code: code,
          message: message,
          field: field,
        ),
      );
    }
  }

  void _compareWithApi({
    required Map<String, String> fields,
    required Map<String, String> apiFields,
    required String field,
    required List<ValidationIssue> issues,
    required String code,
    required String message,
  }) {
    final extracted = fields[field]?.trim().toUpperCase();
    final api = apiFields[field]?.trim().toUpperCase();
    if (
        extracted != null &&
        extracted.isNotEmpty &&
        api != null &&
        api.isNotEmpty &&
        extracted != api) {
      issues.add(
        ValidationIssue(
          layer: ValidationLayer.crossStep,
          code: code,
          message: message,
          field: field,
        ),
      );
    }
  }
}
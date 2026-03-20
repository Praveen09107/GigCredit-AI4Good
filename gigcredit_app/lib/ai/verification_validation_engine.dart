import '../models/enums/document_type.dart';
import 'ai_interfaces.dart';

class VerifiedProfileSnapshot {
  const VerifiedProfileSnapshot({
    this.fullName,
    this.panNumber,
    this.aadhaarLast4,
    this.bankAccountHolder,
    this.bankIfsc,
    this.selfDeclaredMonthlyIncome,
    this.estimatedMonthlyIncome,
  });

  final String? fullName;
  final String? panNumber;
  final String? aadhaarLast4;
  final String? bankAccountHolder;
  final String? bankIfsc;
  final double? selfDeclaredMonthlyIncome;
  final double? estimatedMonthlyIncome;
}

class ValidationContext {
  const ValidationContext({
    this.profile,
    this.apiVerifiedFields = const <String, String>{},
    this.stepTag,
    this.requiredFields = const <String>[],
  });

  final VerifiedProfileSnapshot? profile;
  final Map<String, String> apiVerifiedFields;
  final String? stepTag;
  final List<String> requiredFields;
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
        _requireRegex(
          fields,
          field: 'ifsc_code',
          regex: RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$'),
          issues: issues,
          code: 'BANK_IFSC_FORMAT_INVALID',
          message: 'Bank IFSC failed individual format validation.',
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
      case DocumentType.governmentScheme:
        _requireField(
          fields,
          field: 'scheme_reference',
          issues: issues,
          code: 'SCHEME_REFERENCE_MISSING',
          message: 'Scheme reference is required for government-scheme validation.',
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
          const ValidationIssue(
            layer: ValidationLayer.crossInternal,
            code: 'BILL_AMOUNT_OCR_MISMATCH',
            message: 'Bill amount does not match OCR summary text.',
            field: 'amount',
          ),
        );
      }

      final paymentStatus = fields['payment_status']?.trim().toLowerCase();
      if (paymentStatus != null && paymentStatus.isNotEmpty) {
        final acceptable = {'paid', 'on_time', 'due', 'pending'};
        if (!acceptable.contains(paymentStatus)) {
          issues.add(
            const ValidationIssue(
              layer: ValidationLayer.crossInternal,
              code: 'UTILITY_PAYMENT_STATUS_INVALID',
              message: 'Utility payment status is malformed or unsupported.',
              field: 'payment_status',
            ),
          );
        }
      }
    }

    if (type == DocumentType.itr) {
      final annualIncome = _parseNumber(fields['annual_income']);
      final monthlyIncome = _parseNumber(fields['monthly_income']);
      if (annualIncome != null && monthlyIncome != null) {
        final expectedAnnual = monthlyIncome * 12.0;
        final gap = (annualIncome - expectedAnnual).abs() / expectedAnnual;
        if (expectedAnnual > 0 && gap > 0.35) {
          issues.add(
            const ValidationIssue(
              layer: ValidationLayer.crossInternal,
              code: 'ITR_INCOME_INTERNAL_MISMATCH',
              message: 'ITR annual income and monthly income fields are inconsistent.',
              field: 'annual_income',
            ),
          );
        }
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

      _compareNames(
        extractedName: fields['full_name'],
        profileName: profile.fullName,
        issues: issues,
        code: 'PAN_NAME_PROFILE_MISMATCH',
        message: 'PAN holder name mismatches verified profile name.',
      );
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

      _compareNames(
        extractedName: fields['full_name'],
        profileName: profile.fullName,
        issues: issues,
        code: 'AADHAAR_NAME_PROFILE_MISMATCH',
        message: 'Aadhaar name mismatches verified profile name.',
      );
    }

    if (profile != null && type == DocumentType.bankStatement) {
      _compareIfsc(
        extractedIfsc: fields['ifsc_code'],
        profileIfsc: profile.bankIfsc,
        issues: issues,
        code: 'BANK_IFSC_PROFILE_MISMATCH',
        message: 'Bank IFSC mismatches verified profile IFSC.',
      );

      final profileAccountHolder = profile.bankAccountHolder ?? profile.fullName;
      _compareNames(
        extractedName: fields['account_holder_name'],
        profileName: profileAccountHolder,
        issues: issues,
        code: 'BANK_ACCOUNT_HOLDER_PROFILE_MISMATCH',
        message: 'Bank account holder mismatches verified profile.',
      );
    }

    if (profile != null && type == DocumentType.itr) {
      final annualIncome = _parseNumber(fields['annual_income']);
      final declaredMonthlyIncome = profile.selfDeclaredMonthlyIncome;
      if (annualIncome != null && declaredMonthlyIncome != null && declaredMonthlyIncome > 0) {
        final declaredAnnual = declaredMonthlyIncome * 12.0;
        final ratio = annualIncome / declaredAnnual;
        if (ratio < 0.55 || ratio > 1.75) {
          issues.add(
            const ValidationIssue(
              layer: ValidationLayer.crossStep,
              code: 'ITR_DECLARED_INCOME_MISMATCH',
              message: 'ITR annual income is inconsistent with declared monthly income.',
              field: 'annual_income',
            ),
          );
        }
      }

      final estimatedMonthlyIncome = profile.estimatedMonthlyIncome;
      if (annualIncome != null && estimatedMonthlyIncome != null && estimatedMonthlyIncome > 0) {
        final estimatedAnnual = estimatedMonthlyIncome * 12.0;
        final ratio = annualIncome / estimatedAnnual;
        if (ratio < 0.60 || ratio > 1.40) {
          issues.add(
            const ValidationIssue(
              layer: ValidationLayer.crossStep,
              code: 'ITR_ESTIMATED_INCOME_MISMATCH',
              message: 'ITR annual income is outside allowed range from bank-derived baseline income.',
              field: 'annual_income',
            ),
          );
        }
      }
    }

    if (
        profile != null &&
        (type == DocumentType.electricityBill ||
            type == DocumentType.lpgBill ||
            type == DocumentType.mobileBill ||
            type == DocumentType.wifiBill ||
            type == DocumentType.insurance ||
            type == DocumentType.governmentScheme)) {
      _compareNames(
        extractedName: fields['full_name'],
        profileName: profile.fullName,
        issues: issues,
        code: 'DOC_NAME_PROFILE_MISMATCH',
        message: 'Document holder name mismatches verified profile name.',
      );
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
    if (type == DocumentType.governmentScheme) {
      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'scheme_reference',
        issues: issues,
        code: 'SCHEME_REFERENCE_API_MISMATCH',
        message: 'Scheme reference mismatch against backend verification response.',
      );
    }

    if (type == DocumentType.bankStatement) {
      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'ifsc_code',
        issues: issues,
        code: 'BANK_IFSC_API_MISMATCH',
        message: 'Bank IFSC mismatch against backend verification response.',
      );
      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'account_holder_name',
        issues: issues,
        code: 'BANK_ACCOUNT_HOLDER_API_MISMATCH',
        message: 'Bank account holder mismatch against backend verification response.',
      );
    }

    if (type == DocumentType.itr) {
      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'itr_ack_number',
        issues: issues,
        code: 'ITR_ACK_API_MISMATCH',
        message: 'ITR acknowledgement mismatch against backend verification response.',
      );

      _compareWithApi(
        fields: fields,
        apiFields: context.apiVerifiedFields,
        field: 'pan_number',
        issues: issues,
        code: 'ITR_PAN_API_MISMATCH',
        message: 'ITR PAN mismatch against backend verification response.',
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
    if (value == null || value.isEmpty || _isPlaceholderValue(value)) {
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

  bool _isPlaceholderValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    const placeholders = <String>{
      'unknown',
      'n/a',
      'na',
      'nil',
      'none',
      'not available',
      'not_applicable',
      '-',
      '--',
    };
    return placeholders.contains(normalized);
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

  void _compareNames({
    required String? extractedName,
    required String? profileName,
    required List<ValidationIssue> issues,
    required String code,
    required String message,
  }) {
    final extracted = _normalizeName(extractedName);
    final profile = _normalizeName(profileName);
    if (extracted == null || profile == null) {
      return;
    }
    if (extracted != profile) {
      issues.add(
        ValidationIssue(
          layer: ValidationLayer.crossStep,
          code: code,
          message: message,
          field: 'full_name',
        ),
      );
    }
  }

  void _compareIfsc({
    required String? extractedIfsc,
    required String? profileIfsc,
    required List<ValidationIssue> issues,
    required String code,
    required String message,
  }) {
    final extracted = extractedIfsc?.trim().toUpperCase();
    final profile = profileIfsc?.trim().toUpperCase();
    if (extracted == null || extracted.isEmpty || profile == null || profile.isEmpty) {
      return;
    }
    if (extracted != profile) {
      issues.add(
        ValidationIssue(
          layer: ValidationLayer.crossStep,
          code: code,
          message: message,
          field: 'ifsc_code',
        ),
      );
    }
  }

  String? _normalizeName(String? value) {
    final normalized = value
        ?.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  double? _parseNumber(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }
}
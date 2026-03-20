import 'dart:io';

import '../ai/ai_factory.dart';
import '../ai/ai_interfaces.dart';
import '../ai/ocr_engine.dart';
import '../ai/verification_validation_engine.dart';
import '../config/app_mode.dart';
import '../models/enums/document_type.dart';

class DocumentPipelineService {
  DocumentPipelineService({Future<DocumentProcessor>? processorFuture})
      : _processorFuture = processorFuture ?? AiFactory.resolveDocumentProcessor();

  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;
  static final double _minOcrConfidence = AppMode.ocrConfidenceThreshold;
  static const VerificationValidationEngine _validationEngine = VerificationValidationEngine();
  final Future<DocumentProcessor> _processorFuture;

  Future<ProcessedDocument> processFile({
    required String filePath,
    DocumentType? documentType,
    List<DocumentType>? autoDetectCandidates,
    ValidationContext validationContext = const ValidationContext(),
  }) async {
    if (filePath.trim().isEmpty) {
      throw StateError('Missing local file path.');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Selected file does not exist on device.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Selected file is empty.');
    }

    final processor = await _processorFuture;
    final result = await _processWithDetection(
      processor: processor,
      imageBytes: bytes,
      documentType: documentType,
      autoDetectCandidates: autoDetectCandidates,
      validationContext: validationContext,
    );

    _enforceResultGuards(result);
    return result;
  }

  Future<ProcessedDocument> _processWithDetection({
    required DocumentProcessor processor,
    required List<int> imageBytes,
    required DocumentType? documentType,
    required List<DocumentType>? autoDetectCandidates,
    required ValidationContext validationContext,
  }) async {
    if (documentType != null) {
      final processed = await processor.process(documentType: documentType, imageBytes: imageBytes);
      return _applyContextValidation(processed, validationContext);
    }

    final candidates = (autoDetectCandidates ?? const <DocumentType>[])
        .toSet()
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw StateError('Missing document type and auto-detect candidates.');
    }

    ProcessedDocument? best;
    var bestScore = -1 << 20;

    for (final candidate in candidates) {
      final processed = await processor.process(
        documentType: candidate,
        imageBytes: imageBytes,
      );
      final contextual = _applyContextValidation(processed, validationContext);
      final score = _scoreCandidate(contextual);
      if (best == null || score > bestScore) {
        best = contextual;
        bestScore = score;
      }
    }

    if (best == null) {
      throw StateError('Unable to detect document type from OCR candidates.');
    }

    return best;
  }

  ProcessedDocument _applyContextValidation(
    ProcessedDocument result,
    ValidationContext validationContext,
  ) {
    final contextualFields = _augmentFieldsFromContext(result, validationContext);
    final baseValidation = _validationEngine.run(
      documentType: result.documentType,
      extractedFields: contextualFields,
      context: validationContext,
    );
    final issues = <ValidationIssue>[...baseValidation.issues];
    _appendRequiredFieldIssues(
      documentType: result.documentType,
      fields: contextualFields,
      context: validationContext,
      issues: issues,
    );
    final contextualValidation = ValidationSummary(
      passed: issues.isEmpty,
      issues: issues,
    );

    return ProcessedDocument(
      documentType: result.documentType,
      ocr: result.ocr,
      authenticity: result.authenticity,
      fields: contextualFields,
      validation: contextualValidation,
      metadata: result.metadata,
    );
  }

  void _appendRequiredFieldIssues({
    required DocumentType documentType,
    required Map<String, String> fields,
    required ValidationContext context,
    required List<ValidationIssue> issues,
  }) {
    final required = context.requiredFields.isNotEmpty
        ? context.requiredFields
        : _defaultRequiredFields(documentType, stepTag: context.stepTag);

    for (final field in required) {
      final value = (fields[field] ?? '').trim();
      if (value.isEmpty || value.toUpperCase() == 'UNKNOWN') {
        issues.add(
          ValidationIssue(
            layer: ValidationLayer.crossStep,
            code: 'REQUIRED_FIELD_MISSING',
            message: 'Required field missing for ${context.stepTag ?? documentType.name}: $field',
            field: field,
          ),
        );
      }
    }
  }

  List<String> _defaultRequiredFields(DocumentType documentType, {String? stepTag}) {
    switch (documentType) {
      case DocumentType.aadhaarFront:
        return const <String>['aadhaar_last4'];
      case DocumentType.pan:
        return const <String>['pan_number'];
      case DocumentType.bankStatement:
        return const <String>['statement_id', 'ifsc_code'];
      case DocumentType.electricityBill:
      case DocumentType.lpgBill:
      case DocumentType.mobileBill:
      case DocumentType.wifiBill:
        return const <String>['bill_id', 'amount'];
      case DocumentType.insurance:
        return const <String>['policy_number'];
      case DocumentType.governmentScheme:
        return const <String>['scheme_reference'];
      case DocumentType.itr:
        return const <String>['itr_ack_number', 'annual_income'];
      case DocumentType.rc:
      case DocumentType.aadhaarBack:
        return const <String>[];
    }
  }

  Map<String, String> _augmentFieldsFromContext(
    ProcessedDocument result,
    ValidationContext validationContext,
  ) {
    final merged = Map<String, String>.from(result.fields);
    final raw = result.ocr.rawText;

    bool setFromApiIfMatched(String field) {
      final expected = (validationContext.apiVerifiedFields[field] ?? '').trim();
      if (expected.isEmpty) {
        return false;
      }

      final current = (merged[field] ?? '').trim();
      final isUnknown = current.isEmpty || current.toUpperCase() == 'UNKNOWN';
      if (!isUnknown) {
        return false;
      }

      if (!_containsToken(raw, expected)) {
        return false;
      }

      merged[field] = expected;
      return true;
    }

    // Step-aware enrichment using user-entered/backend-verified identifiers.
    setFromApiIfMatched('pan_number');
    setFromApiIfMatched('aadhaar_last4');
    setFromApiIfMatched('ifsc_code');
    setFromApiIfMatched('account_holder_name');
    setFromApiIfMatched('policy_number');
    setFromApiIfMatched('scheme_reference');
    setFromApiIfMatched('itr_ack_number');
    setFromApiIfMatched('bill_id');

    final profile = validationContext.profile;
    if (profile != null) {
      final currentName = (merged['full_name'] ?? '').trim();
      if (currentName.isEmpty || currentName.toUpperCase() == 'UNKNOWN') {
        final profileName = (profile.fullName ?? '').trim();
        if (profileName.isNotEmpty && _containsNameSignal(raw, profileName)) {
          merged['full_name'] = profileName;
        }
      }

      if (result.documentType == DocumentType.bankStatement) {
        final holder = (merged['account_holder_name'] ?? '').trim();
        final expectedHolder = (profile.bankAccountHolder ?? profile.fullName ?? '').trim();
        if ((holder.isEmpty || holder.toUpperCase() == 'UNKNOWN') &&
            expectedHolder.isNotEmpty &&
            _containsNameSignal(raw, expectedHolder)) {
          merged['account_holder_name'] = expectedHolder;
        }

        final ifsc = (merged['ifsc_code'] ?? '').trim();
        final expectedIfsc = (profile.bankIfsc ?? '').trim().toUpperCase();
        if ((ifsc.isEmpty || ifsc.toUpperCase() == 'UNKNOWN') &&
            expectedIfsc.isNotEmpty &&
            _containsToken(raw, expectedIfsc)) {
          merged['ifsc_code'] = expectedIfsc;
        }
      }
    }

    return merged;
  }

  bool _containsToken(String rawText, String token) {
    final normalizedRaw = _normalizeAlphaNum(rawText);
    final normalizedToken = _normalizeAlphaNum(token);
    if (normalizedRaw.isEmpty || normalizedToken.isEmpty) {
      return false;
    }
    return normalizedRaw.contains(normalizedToken);
  }

  bool _containsNameSignal(String rawText, String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().length >= 3)
        .map(_normalizeAlphaNum)
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return false;
    }

    final normalizedRaw = _normalizeAlphaNum(rawText);
    var matched = 0;
    for (final word in words) {
      if (normalizedRaw.contains(word)) {
        matched += 1;
      }
    }

    return matched >= (words.length >= 2 ? 2 : 1);
  }

  String _normalizeAlphaNum(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  int _scoreCandidate(ProcessedDocument result) {
    var score = 0;
    if (result.ocr.rawText.trim().isNotEmpty) {
      score += 30;
    }
    if (!result.ocr.lowConfidence) {
      score += 20;
    }
    if (result.validation.passed) {
      score += 25;
    }
    if (result.authenticity.label == AuthenticityLabel.real) {
      score += 15;
    }
    if (result.authenticity.confidence >= 0.65) {
      score += 10;
    }

    for (final value in result.fields.values) {
      final v = value.trim();
      if (v.isEmpty) {
        continue;
      }
      score += 3;
      if (v == 'UNKNOWN' || v.contains('BILL-') || v.contains('BS-')) {
        score -= 6;
      }
    }

    return score;
  }

  void _enforceResultGuards(ProcessedDocument result) {
    final documentType = result.documentType;

    if (result.ocr.rawText.contains(kPasswordProtectedPdfMarker)) {
      throw StateError('Password-protected PDF detected for ${documentType.name}. Upload an unlocked PDF or clear image.');
    }

    if (!_hasSufficientTextSignal(result.ocr.rawText)) {
      throw StateError('Document OCR text is insufficient for ${documentType.name}. Retake with clearer capture.');
    }

    if (_requireProductionReadiness) {
      if (!result.validation.passed) {
        throw StateError('Document validation failed for ${documentType.name}.');
      }
      if (result.authenticity.label != AuthenticityLabel.real) {
        throw StateError('Document authenticity check failed for ${documentType.name}.');
      }
      if (result.authenticity.confidence < 0.65) {
        throw StateError('Document authenticity confidence is too low for ${documentType.name}.');
      }
      if (result.ocr.confidence < _minOcrConfidence || result.ocr.lowConfidence || result.ocr.rawText.trim().isEmpty) {
        throw StateError('Document OCR confidence/text is insufficient for ${documentType.name}.');
      }
    }

  }

  bool _hasSufficientTextSignal(String text) {
    final normalized = text.trim();
    if (normalized.length < 16) {
      return false;
    }
    final alphaNumCount = RegExp(r'[A-Za-z0-9]').allMatches(normalized).length;
    return alphaNumCount >= 8;
  }
}

import '../models/enums/document_type.dart';

enum AuthenticityLabel { real, suspicious, edited }

enum ValidationLayer {
  individual,
  crossInternal,
  crossStep,
}

class OcrResult {
  const OcrResult({required this.rawText, required this.confidence});

  final String rawText;
  final double confidence;
}

class AuthenticityResult {
  const AuthenticityResult({required this.label, required this.confidence});

  final AuthenticityLabel label;
  final double confidence;
}

class FaceMatchResult {
  const FaceMatchResult({required this.similarity, required this.passed});

  final double similarity;
  final bool passed;
}

class ValidationIssue {
  const ValidationIssue({
    required this.layer,
    required this.code,
    required this.message,
    this.field,
  });

  final ValidationLayer layer;
  final String code;
  final String message;
  final String? field;
}

class ValidationSummary {
  const ValidationSummary({
    required this.passed,
    required this.issues,
  });

  final bool passed;
  final List<ValidationIssue> issues;
}

class ProcessedDocument {
  const ProcessedDocument({
    required this.documentType,
    required this.ocr,
    required this.authenticity,
    required this.fields,
    this.validation = const ValidationSummary(passed: true, issues: []),
    this.metadata = const <String, String>{},
  });

  final DocumentType documentType;
  final OcrResult ocr;
  final AuthenticityResult authenticity;
  final Map<String, String> fields;
  final ValidationSummary validation;
  final Map<String, String> metadata;
}

abstract class OcrEngine {
  Future<OcrResult> extractText(List<int> imageBytes);
}

abstract class AuthenticityDetector {
  Future<AuthenticityResult> detect(List<int> imageBytes);
}

abstract class FaceVerifier {
  Future<FaceMatchResult> matchFaces(List<int> selfieBytes, List<int> idBytes);
}

abstract class DocumentProcessor {
  Future<ProcessedDocument> process({
    required DocumentType documentType,
    required List<int> imageBytes,
  });
}


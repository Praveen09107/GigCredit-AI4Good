import '../models/enums/document_type.dart';

enum AuthenticityLabel { real, suspicious, edited }

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

class ProcessedDocument {
  const ProcessedDocument({
    required this.documentType,
    required this.ocr,
    required this.authenticity,
    required this.fields,
  });

  final DocumentType documentType;
  final OcrResult ocr;
  final AuthenticityResult authenticity;
  final Map<String, String> fields;
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


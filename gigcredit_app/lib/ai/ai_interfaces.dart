/// Abstract interfaces for on-device AI components (OCR, fraud, face).

abstract class OcrEngine {
  Future<String> extractText(List<int> imageBytes);
}

abstract class AuthenticityDetector {
  Future<bool> isAuthentic(List<int> imageBytes);
}

abstract class FaceVerifier {
  Future<double> matchFaces(List<int> selfieBytes, List<int> idBytes);
}


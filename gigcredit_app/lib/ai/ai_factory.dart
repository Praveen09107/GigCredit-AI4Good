import 'ai_interfaces.dart';
import 'ai_native_bridge.dart';
import 'mock_document_processor.dart';
import 'native_document_processor.dart';

enum AiRuntimeMode {
  mock,
  heuristic,
  nativeBridge,
}

class AiFactory {
  const AiFactory._();

  static DocumentProcessor documentProcessor({
    AiRuntimeMode mode = AiRuntimeMode.nativeBridge,
  }) {
    switch (mode) {
      case AiRuntimeMode.mock:
        return const MockDocumentProcessor();
      case AiRuntimeMode.heuristic:
        return const NativeDocumentProcessor(
          ocrEngine: HeuristicOcrEngine(),
          authenticityDetector: HeuristicAuthenticityDetector(),
        );
      case AiRuntimeMode.nativeBridge:
        return NativeDocumentProcessor.withDefaults();
    }
  }

  static Future<DocumentProcessor> resolveDocumentProcessor({
    AiRuntimeMode preferredMode = AiRuntimeMode.nativeBridge,
  }) async {
    if (preferredMode == AiRuntimeMode.mock) {
      return const MockDocumentProcessor();
    }
    if (preferredMode == AiRuntimeMode.heuristic) {
      return const NativeDocumentProcessor(
        ocrEngine: HeuristicOcrEngine(),
        authenticityDetector: HeuristicAuthenticityDetector(),
      );
    }

    final bridge = NativeAiBridge();
    final nativeReady = await bridge.isAvailable();
    if (!nativeReady) {
      return const NativeDocumentProcessor(
        ocrEngine: HeuristicOcrEngine(),
        authenticityDetector: HeuristicAuthenticityDetector(),
      );
    }
    return NativeDocumentProcessor.withDefaults();
  }
}

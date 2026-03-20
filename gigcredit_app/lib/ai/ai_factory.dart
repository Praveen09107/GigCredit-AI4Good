import 'ai_interfaces.dart';
import 'ai_native_bridge.dart';
import 'ocr_engine.dart';
import '../config/app_mode.dart';
import 'native_document_processor.dart';

enum AiRuntimeMode {
  mock,
  heuristic,
  nativeBridge,
}

class AiFactory {
  const AiFactory._();

  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  static DocumentProcessor documentProcessor({
    AiRuntimeMode mode = AiRuntimeMode.nativeBridge,
  }) {
    if (mode != AiRuntimeMode.nativeBridge) {
      throw StateError('Only nativeBridge AI runtime is supported for on-device processing.');
    }
    return NativeDocumentProcessor.withDefaults();
  }

  static Future<DocumentProcessor> resolveDocumentProcessor({
    AiRuntimeMode preferredMode = AiRuntimeMode.nativeBridge,
  }) async {
    if (preferredMode != AiRuntimeMode.nativeBridge) {
      throw StateError('Only nativeBridge AI runtime is supported for on-device processing.');
    }

    final bridge = NativeAiBridge();
    final nativeReady = await bridge.isAvailable();
    if (!nativeReady) {
      if (!_requireProductionReadiness) {
        return const NativeDocumentProcessor(
          ocrEngine: PdfTextStreamOcrEngine(),
          authenticityDetector: HeuristicAuthenticityDetector(),
        );
      }
      throw StateError('Native AI runtime is unavailable for on-device processing.');
    }
    return NativeDocumentProcessor.withDefaults();
  }
}

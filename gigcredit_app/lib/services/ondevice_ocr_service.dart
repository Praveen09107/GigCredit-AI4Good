import 'dart:io';
import 'dart:async';

import '../ai/ai_native_bridge.dart';
import '../ai/ocr_engine.dart';
import '../config/app_mode.dart';

class OnDeviceOcrResult {
  const OnDeviceOcrResult({
    required this.rawText,
    required this.confidence,
    required this.source,
  });

  final String rawText;
  final double confidence;
  final String source;

  bool get hasUsableText => rawText.trim().length >= 16;
}

class OnDeviceOcrService {
  const OnDeviceOcrService({
    NativeAiBridge? bridge,
    bool? requireProductionReadiness,
  })  : _bridge = bridge,
        _requireProductionReadiness =
            requireProductionReadiness ?? AppMode.requireProductionReadiness;

  final NativeAiBridge? _bridge;
  final bool _requireProductionReadiness;
  static const Duration _healthTimeout = Duration(seconds: 4);
  static const Duration _ocrTimeout = Duration(seconds: 10);

  Future<OnDeviceOcrResult> extractFromFile({
    required String filePath,
    String? docHint,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const OnDeviceOcrResult(
        rawText: '',
        confidence: 0.0,
        source: 'missing_file',
      );
    }

    final bytes = await file.readAsBytes();
    final extension = _extensionOf(filePath);

    final native = await _tryNativeOcr(bytes: bytes, extension: extension, docHint: docHint);
    if (native != null && native.rawText.trim().isNotEmpty) {
      return native;
    }

    if (!_requireProductionReadiness) {
      final local = await _tryLocalOnDeviceFallback(bytes: bytes);
      if (local != null && local.rawText.trim().isNotEmpty) {
        return local;
      }
    }

    return const OnDeviceOcrResult(
      rawText: '',
      confidence: 0.0,
      source: 'native_required_unavailable',
    );
  }

  Future<OnDeviceOcrResult?> _tryNativeOcr({
    required List<int> bytes,
    required String extension,
    String? docHint,
  }) async {
    final bridge = _bridge ?? NativeAiBridge();
    try {
      final health = await bridge.getHealth().timeout(_healthTimeout);
      if (!health.supportsOcr) {
        return null;
      }
      final ocr = await bridge.extractText(
        bytes,
        meta: <String, Object?>{
          'fileExt': extension,
          'docHint': docHint ?? '',
          'byteCount': bytes.length,
        },
      ).timeout(_ocrTimeout);
      return OnDeviceOcrResult(
        rawText: ocr.rawText,
        confidence: ocr.confidence,
        source: 'native_bridge',
      );
    } on NativeBridgeException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  Future<OnDeviceOcrResult?> _tryLocalOnDeviceFallback({
    required List<int> bytes,
  }) async {
    const localEngine = PdfTextStreamOcrEngine();
    final result = await localEngine.extractText(bytes);
    if (!_looksLikeReadableText(result.rawText)) {
      return null;
    }
    return OnDeviceOcrResult(
      rawText: result.rawText,
      confidence: result.confidence,
      source: 'local_pdf_text_stream',
    );
  }

  bool _looksLikeReadableText(String text) {
    if (text.isEmpty || text.length < 16) {
      return false;
    }
    final printable = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
    return printable >= 8;
  }

  String _extensionOf(String path) {
    final index = path.lastIndexOf('.');
    if (index < 0 || index == path.length - 1) {
      return '';
    }
    return path.substring(index + 1).toLowerCase();
  }
}

import 'dart:async';

import 'package:flutter/services.dart';

import 'ai_interfaces.dart';

class NativeRuntimeHealth {
  const NativeRuntimeHealth({
    required this.ready,
    required this.engineVersion,
    required this.modelsLoaded,
    required this.fetchedAt,
    required this.ocrRuntimeAvailable,
    required this.tfliteRuntimeAvailable,
    required this.authenticityModelAvailable,
    required this.faceModelAvailable,
  });

  final bool ready;
  final String engineVersion;
  final bool modelsLoaded;
  final DateTime fetchedAt;
  final bool? ocrRuntimeAvailable;
  final bool? tfliteRuntimeAvailable;
  final bool? authenticityModelAvailable;
  final bool? faceModelAvailable;

  bool get supportsOcr => ready && (ocrRuntimeAvailable ?? true);

  bool get supportsAuthenticity =>
      ready &&
      (tfliteRuntimeAvailable ?? true) &&
      (authenticityModelAvailable ?? true);

  bool get supportsFaceMatch =>
      ready && (tfliteRuntimeAvailable ?? true) && (faceModelAvailable ?? true);
}

class NativeBridgeException implements Exception {
  const NativeBridgeException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'NativeBridgeException(code: $code, message: $message)';
}

class NativeAiBridge {
  NativeAiBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'gigcredit/ai_native';
  static const Duration _healthTtl = Duration(seconds: 30);
  final MethodChannel _channel;
  NativeRuntimeHealth? _healthCache;
  DateTime? _healthFetchedAt;

  Future<bool> isAvailable() async {
    try {
      final health = await getHealth();
      return health.ready;
    } on NativeBridgeException {
      return false;
    }
  }

  Future<NativeRuntimeHealth> getHealth({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _healthCache != null &&
        _healthFetchedAt != null &&
        now.difference(_healthFetchedAt!) <= _healthTtl) {
      return _healthCache!;
    }

    final payload = await _invoke<Map<dynamic, dynamic>>(
      method: 'ai.health',
      arguments: const {},
      timeout: const Duration(seconds: 2),
    );

    final health = NativeRuntimeHealth(
      ready: payload['ready'] == true,
      engineVersion: (payload['engineVersion'] ?? '').toString(),
      modelsLoaded: payload['modelsLoaded'] == true,
      fetchedAt: now,
      ocrRuntimeAvailable: _boolOrNull(payload['ocrRuntimeAvailable']),
      tfliteRuntimeAvailable: _boolOrNull(payload['tfliteRuntimeAvailable']),
      authenticityModelAvailable: _boolOrNull(payload['authenticityModelAvailable']),
      faceModelAvailable: _boolOrNull(payload['faceModelAvailable']),
    );

    _healthCache = health;
    _healthFetchedAt = now;
    return health;
  }

  Future<OcrResult> extractText(
    List<int> imageBytes, {
    Map<String, Object?>? meta,
  }) async {
    final arguments = <String, Object?>{'imageBytes': imageBytes};
    if (meta != null && meta.isNotEmpty) {
      arguments['meta'] = meta;
    }
    final payload = await _invoke<Map<dynamic, dynamic>>(
      method: 'ocr.extractText',
      arguments: arguments,
    );
    final rawText = (payload['rawText'] ?? '').toString();
    final confidence = (payload['confidence'] as num?)?.toDouble() ?? 0.0;
    final blocks = _parseBlocks(payload['blocks']);
    final avgConfidence = blocks.isEmpty
        ? confidence.clamp(0.0, 1.0)
        : blocks
                .map((block) => block.confidence)
                .reduce((a, b) => a + b) /
            blocks.length;
    return OcrResult(
      rawText: rawText,
      confidence: confidence.clamp(0.0, 1.0),
      blocks: blocks,
      lowConfidence: avgConfidence < 0.70,
    );
  }

  Future<AuthenticityResult> detectAuthenticity(List<int> imageBytes) async {
    final payload = await _invoke<Map<dynamic, dynamic>>(
      method: 'authenticity.detect',
      arguments: {'imageBytes': imageBytes},
    );
    final rawLabel = (payload['label'] ?? 'suspicious').toString();
    final confidence = (payload['confidence'] as num?)?.toDouble() ?? 0.0;
    return AuthenticityResult(
      label: _parseAuthenticityLabel(rawLabel),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  Future<FaceMatchResult> matchFaces(
    List<int> selfieBytes,
    List<int> idBytes,
  ) async {
    final payload = await _invoke<Map<dynamic, dynamic>>(
      method: 'face.match',
      arguments: {'selfieBytes': selfieBytes, 'idBytes': idBytes},
    );
    final similarity = (payload['similarity'] as num?)?.toDouble() ?? 0.0;
    final passed = payload['passed'] == true;
    return FaceMatchResult(similarity: similarity.clamp(0.0, 1.0), passed: passed);
  }

  Future<void> configureModelPaths(Map<String, String> modelPaths) async {
    if (modelPaths.isEmpty) {
      return;
    }

    try {
      await _invoke<Map<dynamic, dynamic>>(
        method: 'ai.configureModels',
        arguments: <String, Object?>{'modelPaths': modelPaths},
        timeout: const Duration(seconds: 3),
      );
      _healthCache = null;
      _healthFetchedAt = null;
    } on NativeBridgeException {
      // Configuration is best-effort for prototype compatibility.
      return;
    }
  }

  Future<T> _invoke<T>({
    required String method,
    required Map<String, Object?> arguments,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final response = await _channel
          .invokeMethod<dynamic>(method, arguments)
          .timeout(timeout);
      if (response is T) {
        return response;
      }
      throw NativeBridgeException('bad_response', 'Unexpected response type for $method');
    } on TimeoutException {
      throw const NativeBridgeException('timeout', 'Native AI call timed out');
    } on MissingPluginException {
      throw const NativeBridgeException('missing_plugin', 'Native AI plugin not registered');
    } on PlatformException catch (error) {
      throw NativeBridgeException(
        error.code,
        error.message ?? 'Platform error during $method',
      );
    }
  }

  static AuthenticityLabel _parseAuthenticityLabel(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'real') {
      return AuthenticityLabel.real;
    }
    if (normalized == 'edited') {
      return AuthenticityLabel.edited;
    }
    return AuthenticityLabel.suspicious;
  }

  static bool? _boolOrNull(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  static List<OcrBlock> _parseBlocks(Object? rawBlocks) {
    if (rawBlocks is! List) {
      return const <OcrBlock>[];
    }

    final blocks = <OcrBlock>[];
    for (final entry in rawBlocks) {
      if (entry is Map) {
        final text = (entry['text'] ?? '').toString();
        final confidence = (entry['confidence'] as num?)?.toDouble() ?? 0.0;
        if (text.trim().isNotEmpty) {
          blocks.add(OcrBlock(text: text.trim(), confidence: confidence.clamp(0.0, 1.0)));
        }
      }
    }
    return blocks;
  }
}

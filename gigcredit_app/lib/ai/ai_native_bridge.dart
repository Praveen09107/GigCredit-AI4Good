import 'dart:async';

import 'package:flutter/services.dart';

import 'ai_interfaces.dart';

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
  final MethodChannel _channel;

  Future<bool> isAvailable() async {
    try {
      final payload = await _invoke<Map<dynamic, dynamic>>(
        method: 'ai.health',
        arguments: const {},
        timeout: const Duration(seconds: 2),
      );
      return payload['ready'] == true;
    } on NativeBridgeException {
      return false;
    }
  }

  Future<OcrResult> extractText(List<int> imageBytes) async {
    final payload = await _invoke<Map<dynamic, dynamic>>(
      method: 'ocr.extractText',
      arguments: {'imageBytes': imageBytes},
    );
    final rawText = (payload['rawText'] ?? '').toString();
    final confidence = (payload['confidence'] as num?)?.toDouble() ?? 0.0;
    return OcrResult(rawText: rawText, confidence: confidence.clamp(0.0, 1.0));
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
}

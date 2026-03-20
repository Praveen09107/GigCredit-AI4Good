import 'dart:convert';

import 'package:crypto/crypto.dart';

String computeRequestSignature({
  required String apiKey,
  required String deviceId,
  required String timestamp,
  required String body,
}) {
  final bodyHash = sha256.convert(utf8.encode(body)).toString();
  final canonical = '$deviceId$timestamp$bodyHash';
  final digest = Hmac(sha256, utf8.encode(apiKey)).convert(utf8.encode(canonical));
  return digest.toString();
}

String Function(String, String, String) signatureProviderFromApiKey(String apiKey) {
  return (String deviceId, String timestamp, String body) {
    return computeRequestSignature(
      apiKey: apiKey,
      deviceId: deviceId,
      timestamp: timestamp,
      body: body,
    );
  };
}

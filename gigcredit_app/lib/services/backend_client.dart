import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal placeholder backend client.
class BackendClient {
  BackendClient({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  Future<http.Response> postJson(String path, Map<String, dynamic> body) {
    final uri = Uri.parse('$baseUrl$path');
    return http.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: jsonEncode(body),
    );
  }
}


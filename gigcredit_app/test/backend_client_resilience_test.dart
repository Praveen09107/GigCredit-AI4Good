import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/services/backend_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BackendClient resilience', () {
    BackendClient buildClient({
      required http.Client client,
      Duration? timeout,
      int? maxRetries,
      Duration? initialRetryDelay,
    }) {
      return BackendClient(
        baseUrl: 'https://example.test',
        apiKey: 'api-key',
        deviceId: 'device-123',
        signatureProvider: (_, __, ___) => 'sig',
        client: client,
        requestTimeout: timeout,
        maxRetries: maxRetries,
        initialRetryDelay: initialRetryDelay,
      );
    }

    test('throws unauthorized without retry on 401', () async {
      var attempts = 0;
      final client = buildClient(
        client: MockClient((_) async {
          attempts += 1;
          return http.Response(
            jsonEncode({'status': 'ERROR', 'error': 'Invalid API key'}),
            401,
          );
        }),
        maxRetries: 3,
        initialRetryDelay: Duration.zero,
      );

      final future = client.verifyPan('ABCDE1234F');

      await expectLater(
        future,
        throwsA(
          isA<BackendClientException>()
              .having((e) => e.type, 'type', BackendErrorType.unauthorized)
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.attempts, 'attempts', 1),
        ),
      );
      expect(attempts, 1);
    });

    test('retries on timeout and then throws timeout error', () async {
      var attempts = 0;
      final client = buildClient(
        client: MockClient((_) async {
          attempts += 1;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(jsonEncode({'status': 'OK'}), 200);
        }),
        timeout: const Duration(milliseconds: 5),
        maxRetries: 2,
        initialRetryDelay: Duration.zero,
      );

      final future = client.verifyIfsc('HDFC0001234');

      await expectLater(
        future,
        throwsA(
          isA<BackendClientException>()
              .having((e) => e.type, 'type', BackendErrorType.timeout)
              .having((e) => e.attempts, 'attempts', 3),
        ),
      );
      expect(attempts, 3);
    });

    test('recovers from transient server failure after retry', () async {
      var attempts = 0;
      final client = buildClient(
        client: MockClient((_) async {
          attempts += 1;
          if (attempts == 1) {
            return http.Response(
              jsonEncode({'status': 'ERROR', 'error': 'temporary outage'}),
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'data': {'verified': true},
            }),
            200,
          );
        }),
        maxRetries: 2,
        initialRetryDelay: Duration.zero,
      );

      final envelope = await client.verifyAadhaar('1234');

      expect(envelope.status, 'OK');
      expect(envelope.data?['verified'], true);
      expect(attempts, 2);
    });
  });
}

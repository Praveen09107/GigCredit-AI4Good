import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client_interface.dart';

enum BackendErrorType {
  timeout,
  network,
  unauthorized,
  forbidden,
  rateLimited,
  server,
  invalidResponse,
  unknown,
}

class BackendClientException implements Exception {
  const BackendClientException({
    required this.type,
    required this.message,
    this.path,
    this.statusCode,
    this.attempts = 1,
    this.retriable = false,
  });

  final BackendErrorType type;
  final String message;
  final String? path;
  final int? statusCode;
  final int attempts;
  final bool retriable;

  @override
  String toString() {
    return 'BackendClientException(type: $type, statusCode: $statusCode, attempts: $attempts, retriable: $retriable, message: $message)';
  }
}

class BackendClient implements ApiClientInterface {
  BackendClient({
    required this.baseUrl,
    required this.apiKey,
    required this.deviceId,
    required this.signatureProvider,
    http.Client? client,
    Duration? requestTimeout,
    int? maxRetries,
    Duration? initialRetryDelay,
  }) : _client = client ?? http.Client(),
       requestTimeout = requestTimeout ?? const Duration(seconds: 8),
       maxRetries = maxRetries ?? 1,
       initialRetryDelay = initialRetryDelay ?? const Duration(milliseconds: 350);

  final String baseUrl;
  final String apiKey;
  final String deviceId;
  final String Function(String deviceId, String timestamp, String body) signatureProvider;
  final http.Client _client;
  final Duration requestTimeout;
  final int maxRetries;
  final Duration initialRetryDelay;

  Future<ApiResponseEnvelope> postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = jsonEncode(body);
    var attempt = 0;
    BackendClientException? lastRetriableError;

    while (attempt <= maxRetries) {
      attempt += 1;
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = signatureProvider(deviceId, timestamp, encodedBody);

      try {
        final response = await _client
            .post(
              uri,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'X-API-Key': apiKey,
                'X-Device-ID': deviceId,
                'X-Timestamp': timestamp,
                'X-Signature': signature,
              },
              body: encodedBody,
            )
            .timeout(requestTimeout);

        final decoded = _tryDecodeJson(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (decoded == null) {
            throw BackendClientException(
              type: BackendErrorType.invalidResponse,
              message: 'Backend returned non-JSON response.',
              path: path,
              statusCode: response.statusCode,
              attempts: attempt,
            );
          }
          return ApiResponseEnvelope.fromJson(decoded);
        }

        final exception = _exceptionFromStatus(
          statusCode: response.statusCode,
          path: path,
          attempt: attempt,
          decodedBody: decoded,
        );

        if (exception.retriable && attempt <= maxRetries) {
          lastRetriableError = exception;
          await _sleepBackoff(attempt);
          continue;
        }

        throw exception;
      } on TimeoutException {
        final exception = BackendClientException(
          type: BackendErrorType.timeout,
          message: 'Request timed out while calling backend.',
          path: path,
          attempts: attempt,
          retriable: true,
        );
        if (attempt <= maxRetries) {
          lastRetriableError = exception;
          await _sleepBackoff(attempt);
          continue;
        }
        throw exception;
      } on SocketException {
        final exception = BackendClientException(
          type: BackendErrorType.network,
          message: 'Network error while calling backend.',
          path: path,
          attempts: attempt,
          retriable: true,
        );
        if (attempt <= maxRetries) {
          lastRetriableError = exception;
          await _sleepBackoff(attempt);
          continue;
        }
        throw exception;
      }
    }

    throw lastRetriableError ??
        BackendClientException(
          type: BackendErrorType.unknown,
          message: 'Backend request failed after retries.',
          path: path,
          attempts: maxRetries + 1,
        );
  }

  Map<String, dynamic>? _tryDecodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  BackendClientException _exceptionFromStatus({
    required int statusCode,
    required String path,
    required int attempt,
    Map<String, dynamic>? decodedBody,
  }) {
    final bodyError = decodedBody?['error']?.toString();
    final message = bodyError == null || bodyError.trim().isEmpty
        ? 'Backend request failed with status $statusCode.'
        : bodyError;

    if (statusCode == 401) {
      return BackendClientException(
        type: BackendErrorType.unauthorized,
        message: message,
        path: path,
        statusCode: statusCode,
        attempts: attempt,
      );
    }
    if (statusCode == 403) {
      return BackendClientException(
        type: BackendErrorType.forbidden,
        message: message,
        path: path,
        statusCode: statusCode,
        attempts: attempt,
      );
    }
    if (statusCode == 429) {
      return BackendClientException(
        type: BackendErrorType.rateLimited,
        message: message,
        path: path,
        statusCode: statusCode,
        attempts: attempt,
        retriable: true,
      );
    }
    if (statusCode >= 500) {
      return BackendClientException(
        type: BackendErrorType.server,
        message: message,
        path: path,
        statusCode: statusCode,
        attempts: attempt,
        retriable: true,
      );
    }
    return BackendClientException(
      type: BackendErrorType.invalidResponse,
      message: message,
      path: path,
      statusCode: statusCode,
      attempts: attempt,
    );
  }

  Future<void> _sleepBackoff(int attempt) {
    final factor = attempt <= 1 ? 1 : (1 << (attempt - 1));
    final delay = Duration(milliseconds: initialRetryDelay.inMilliseconds * factor);
    return Future<void>.delayed(delay);
  }

  @override
  Future<ApiResponseEnvelope> verifyPan(String pan) {
    return postJson('/verify/pan', <String, dynamic>{'identifier': pan});
  }

  @override
  Future<ApiResponseEnvelope> verifyAadhaar(String aadhaarOrLast4) {
    return postJson('/verify/aadhaar', <String, dynamic>{
      'identifier': aadhaarOrLast4,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyIfsc(String ifsc) {
    return postJson('/verify/bank/ifsc', <String, dynamic>{'identifier': ifsc});
  }

  @override
  Future<ApiResponseEnvelope> verifyBankAccount(String accountHash) {
    return postJson('/verify/bank/account', <String, dynamic>{
      'identifier': accountHash,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyVehicleRc(String rcNumber) {
    return postJson('/verify/vehicle/rc', <String, dynamic>{
      'identifier': rcNumber,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyInsurance(String policyNumber) {
    return postJson('/verify/insurance', <String, dynamic>{
      'identifier': policyNumber,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyItr(String itrAck) {
    return postJson('/verify/income-tax/itr', <String, dynamic>{
      'identifier': itrAck,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyEshram(String eshramNumber) {
    return postJson('/verify/eshram', <String, dynamic>{
      'identifier': eshramNumber,
    });
  }

  @override
  Future<ApiResponseEnvelope> checkLoan(String loanId) {
    return postJson('/verify/loan', <String, dynamic>{'identifier': loanId});
  }

  @override
  Future<ApiResponseEnvelope> generateReport(Map<String, dynamic> payload) {
    return postJson('/report/generate', payload);
  }

  @override
  Future<ApiResponseEnvelope> storeReport(Map<String, dynamic> payload) {
    return postJson('/report/store', payload);
  }
}


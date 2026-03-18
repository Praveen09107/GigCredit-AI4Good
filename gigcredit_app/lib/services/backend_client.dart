import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client_interface.dart';

class BackendClient implements ApiClientInterface {
  BackendClient({
    required this.baseUrl,
    required this.apiKey,
    required this.deviceId,
    required this.signatureProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final String deviceId;
  final String Function(String deviceId, String timestamp, String body) signatureProvider;
  final http.Client _client;

  Future<ApiResponseEnvelope> postJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final encodedBody = jsonEncode(body);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = signatureProvider(deviceId, timestamp, encodedBody);

    final response = await _client.post(
      uri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
        'X-Device-ID': deviceId,
        'X-Timestamp': timestamp,
        'X-Signature': signature,
      },
      body: encodedBody,
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ApiResponseEnvelope.fromJson(decoded);
  }

  @override
  Future<ApiResponseEnvelope> verifyPan(String pan) {
    return postJson('/gov/pan/verify', <String, dynamic>{'identifier': pan});
  }

  @override
  Future<ApiResponseEnvelope> verifyAadhaar(String aadhaarOrLast4) {
    return postJson('/gov/aadhaar/verify', <String, dynamic>{
      'identifier': aadhaarOrLast4,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyIfsc(String ifsc) {
    return postJson('/bank/ifsc/verify', <String, dynamic>{'identifier': ifsc});
  }

  @override
  Future<ApiResponseEnvelope> verifyBankAccount(String accountHash) {
    return postJson('/bank/account/verify', <String, dynamic>{
      'identifier': accountHash,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyVehicleRc(String rcNumber) {
    return postJson('/gov/vehicle/rc/verify', <String, dynamic>{
      'identifier': rcNumber,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyInsurance(String policyNumber) {
    return postJson('/gov/insurance/verify', <String, dynamic>{
      'identifier': policyNumber,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyItr(String itrAck) {
    return postJson('/gov/income-tax/itr/verify', <String, dynamic>{
      'identifier': itrAck,
    });
  }

  @override
  Future<ApiResponseEnvelope> verifyEshram(String eshramNumber) {
    return postJson('/gov/eshram/verify', <String, dynamic>{
      'identifier': eshramNumber,
    });
  }

  @override
  Future<ApiResponseEnvelope> checkLoan(String loanId) {
    return postJson('/bank/loan/check', <String, dynamic>{'identifier': loanId});
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


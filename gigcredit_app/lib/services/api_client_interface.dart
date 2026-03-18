class ApiResponseEnvelope {
  const ApiResponseEnvelope({
    required this.status,
    this.data,
    this.error,
    this.traceId,
  });

  final String status;
  final Map<String, dynamic>? data;
  final String? error;
  final String? traceId;

  factory ApiResponseEnvelope.fromJson(Map<String, dynamic> json) {
    return ApiResponseEnvelope(
      status: json['status'] as String? ?? 'ERROR',
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      traceId: json['trace_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data,
      'error': error,
      'trace_id': traceId,
    };
  }
}

abstract class ApiClientInterface {
  Future<ApiResponseEnvelope> verifyPan(String pan);
  Future<ApiResponseEnvelope> verifyAadhaar(String aadhaarOrLast4);
  Future<ApiResponseEnvelope> verifyIfsc(String ifsc);
  Future<ApiResponseEnvelope> verifyBankAccount(String accountHash);
  Future<ApiResponseEnvelope> verifyVehicleRc(String rcNumber);
  Future<ApiResponseEnvelope> verifyInsurance(String policyNumber);
  Future<ApiResponseEnvelope> verifyItr(String itrAck);
  Future<ApiResponseEnvelope> verifyEshram(String eshramNumber);
  Future<ApiResponseEnvelope> checkLoan(String loanId);
  Future<ApiResponseEnvelope> generateReport(Map<String, dynamic> payload);
  Future<ApiResponseEnvelope> storeReport(Map<String, dynamic> payload);
}

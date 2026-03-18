import 'api_client_interface.dart';

class MockApiClient implements ApiClientInterface {
  const MockApiClient();

  @override
  Future<ApiResponseEnvelope> verifyPan(String pan) async {
    if (pan.toUpperCase() == 'ABCDE1234F') {
      return const ApiResponseEnvelope(
        status: 'FOUND',
        data: {
          'pan_number': 'ABCDE1234F',
          'full_name': 'RAVI KUMAR',
          'status': 'ACTIVE',
        },
      );
    }
    return const ApiResponseEnvelope(status: 'NOT_FOUND');
  }

  @override
  Future<ApiResponseEnvelope> verifyAadhaar(String aadhaarOrLast4) async {
    final last4 = aadhaarOrLast4.length >= 4
        ? aadhaarOrLast4.substring(aadhaarOrLast4.length - 4)
        : aadhaarOrLast4;
    if (last4 == '4123') {
      return const ApiResponseEnvelope(
        status: 'FOUND',
        data: {
          'aadhaar_last4': '4123',
          'full_name': 'RAVI KUMAR',
          'status': 'ACTIVE',
        },
      );
    }
    return const ApiResponseEnvelope(status: 'NOT_FOUND');
  }

  @override
  Future<ApiResponseEnvelope> verifyIfsc(String ifsc) async {
    if (ifsc.toUpperCase() == 'HDFC0001234') {
      return const ApiResponseEnvelope(
        status: 'FOUND',
        data: {
          'ifsc_code': 'HDFC0001234',
          'bank_name': 'HDFC Bank',
          'branch': 'Koramangala',
        },
      );
    }
    return const ApiResponseEnvelope(status: 'NOT_FOUND');
  }

  @override
  Future<ApiResponseEnvelope> verifyBankAccount(String accountHash) async {
    if (accountHash.isNotEmpty) {
      return const ApiResponseEnvelope(
        status: 'FOUND',
        data: {
          'account_holder_name': 'RAVI KUMAR',
          'ifsc_code': 'HDFC0001234',
          'status': 'ACTIVE',
        },
      );
    }
    return const ApiResponseEnvelope(status: 'INVALID', error: 'Missing account hash');
  }

  @override
  Future<ApiResponseEnvelope> verifyVehicleRc(String rcNumber) async {
    return ApiResponseEnvelope(
      status: rcNumber.isEmpty ? 'INVALID' : 'FOUND',
      data: rcNumber.isEmpty
          ? null
          : {
              'rc_number': rcNumber.toUpperCase(),
              'status': 'ACTIVE',
            },
      error: rcNumber.isEmpty ? 'Missing RC number' : null,
    );
  }

  @override
  Future<ApiResponseEnvelope> verifyInsurance(String policyNumber) async {
    return ApiResponseEnvelope(
      status: policyNumber.isEmpty ? 'INVALID' : 'FOUND',
      data: policyNumber.isEmpty
          ? null
          : {
              'policy_number': policyNumber.toUpperCase(),
              'status': 'ACTIVE',
            },
      error: policyNumber.isEmpty ? 'Missing policy number' : null,
    );
  }

  @override
  Future<ApiResponseEnvelope> verifyItr(String itrAck) async {
    return ApiResponseEnvelope(
      status: itrAck.isEmpty ? 'INVALID' : 'FOUND',
      data: itrAck.isEmpty
          ? null
          : {
              'itr_ack_number': itrAck.toUpperCase(),
              'status': 'FILED',
            },
      error: itrAck.isEmpty ? 'Missing ITR acknowledgement' : null,
    );
  }

  @override
  Future<ApiResponseEnvelope> verifyEshram(String eshramNumber) async {
    return ApiResponseEnvelope(
      status: eshramNumber.isEmpty ? 'INVALID' : 'FOUND',
      data: eshramNumber.isEmpty
          ? null
          : {
              'eshram_number': eshramNumber,
              'status': 'ACTIVE',
            },
      error: eshramNumber.isEmpty ? 'Missing eShram number' : null,
    );
  }

  @override
  Future<ApiResponseEnvelope> checkLoan(String loanId) async {
    return ApiResponseEnvelope(
      status: loanId.isEmpty ? 'NOT_FOUND' : 'FOUND',
      data: loanId.isEmpty
          ? null
          : {
              'loan_id': loanId,
              'loan_status': 'Active',
              'emi_amount': 4250,
            },
    );
  }

  @override
  Future<ApiResponseEnvelope> generateReport(Map<String, dynamic> payload) async {
    final score = payload['score'];
    return ApiResponseEnvelope(
      status: 'OK',
      data: {
        'explanation': 'Mock report generated successfully for score $score.',
        'suggestions': const [
          'Pay bills on time.',
          'Keep EMI ratio under control.',
          'Maintain stable monthly credits.',
        ],
      },
    );
  }

  @override
  Future<ApiResponseEnvelope> storeReport(Map<String, dynamic> payload) async {
    return const ApiResponseEnvelope(status: 'OK', data: {'stored': true});
  }
}

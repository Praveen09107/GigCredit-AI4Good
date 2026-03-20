import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step9_validators.dart';

void main() {
  group('Step9Validators.fallbackLoanHookPass', () {
    test('passes for normal lender names', () {
      expect(Step9Validators.fallbackLoanHookPass('HDFC Bank'), isTrue);
      expect(Step9Validators.fallbackLoanHookPass('ICICI'), isTrue);
    });

    test('fails for test-like or very short names', () {
      expect(Step9Validators.fallbackLoanHookPass('te'), isFalse);
      expect(Step9Validators.fallbackLoanHookPass('test lender'), isFalse);
    });
  });

  group('Step9Validators.strictModeLoanGateError', () {
    test('returns error in strict mode when loan verification failed', () {
      final err = Step9Validators.strictModeLoanGateError(
        requireProductionReadiness: true,
        loanVerificationPassed: false,
      );

      expect(err, isNotNull);
    });

    test('returns null when strict mode condition is satisfied', () {
      final strictOk = Step9Validators.strictModeLoanGateError(
        requireProductionReadiness: true,
        loanVerificationPassed: true,
      );
      final integrationOk = Step9Validators.strictModeLoanGateError(
        requireProductionReadiness: false,
        loanVerificationPassed: false,
      );

      expect(strictOk, isNull);
      expect(integrationOk, isNull);
    });
  });
}

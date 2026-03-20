import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step5_validators.dart';

void main() {
  group('Step5Validators.isBackendVerificationAccepted', () {
    test('accepts when production readiness is disabled', () {
      final accepted = Step5Validators.isBackendVerificationAccepted(
        requireProductionReadiness: false,
        backendVerified: false,
      );

      expect(accepted, isTrue);
    });

    test('requires backend verification when production readiness is enabled', () {
      final rejected = Step5Validators.isBackendVerificationAccepted(
        requireProductionReadiness: true,
        backendVerified: false,
      );
      final accepted = Step5Validators.isBackendVerificationAccepted(
        requireProductionReadiness: true,
        backendVerified: true,
      );

      expect(rejected, isFalse);
      expect(accepted, isTrue);
    });
  });
}

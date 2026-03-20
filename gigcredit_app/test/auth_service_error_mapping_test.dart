import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/services/auth_service.dart';

void main() {
  group('AuthService OTP error mapping', () {
    final service = AuthService();

    test('maps operation-not-allowed to phone provider message', () {
      final message = service.mapFirebaseErrorForUi(
        FirebaseAuthException(code: 'operation-not-allowed'),
      );
      expect(message, contains('Phone OTP is not enabled'));
    });

    test('maps invalid-verification-code to retry message', () {
      final message = service.mapFirebaseErrorForUi(
        FirebaseAuthException(code: 'invalid-verification-code'),
      );
      expect(message, contains('Incorrect OTP'));
    });

    test('maps session-expired to resend message', () {
      final message = service.mapFirebaseErrorForUi(
        FirebaseAuthException(code: 'session-expired'),
      );
      expect(message, contains('OTP expired'));
    });

    test('maps recaptcha/site-key failure from firebase exception', () {
      final message = service.mapFirebaseErrorForUi(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'No Recaptcha Enterprise siteKey configured for tenant/project',
        ),
      );
      expect(message.toLowerCase(), contains('recaptcha'));
    });

    test('maps non-firebase recaptcha errors', () {
      final message = service.mapAnyErrorForUi(
        Exception('Failed to initialize reCAPTCHA config: No siteKey configured'),
      );
      expect(message.toLowerCase(), contains('recaptcha'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step2_validators.dart';

void main() {
  group('Step2Validators', () {
    test('validateAadhaar accepts exactly 12 digits', () {
      expect(Step2Validators.validateAadhaar('123456789012'), isNull);
      expect(Step2Validators.validateAadhaar('1234 5678 9012'), isNull);
    });

    test('validateAadhaar rejects invalid formats', () {
      expect(Step2Validators.validateAadhaar('12345678901'), isNotNull);
      expect(Step2Validators.validateAadhaar('1234567890123'), isNotNull);
      expect(Step2Validators.validateAadhaar('1234ABCD9012'), isNotNull);
    });

    test('validatePan accepts canonical PAN format', () {
      expect(Step2Validators.validatePan('ABCDE1234F'), isNull);
      expect(Step2Validators.validatePan('abcde1234f'), isNull);
    });

    test('validatePan rejects invalid PAN format', () {
      expect(Step2Validators.validatePan('ABCD1234F'), isNotNull);
      expect(Step2Validators.validatePan('ABCDE12345'), isNotNull);
      expect(Step2Validators.validatePan('ABCDE123F'), isNotNull);
    });

    test('normalizers sanitize PAN and Aadhaar', () {
      expect(Step2Validators.normalizePan(' abcde1234f '), 'ABCDE1234F');
      expect(Step2Validators.normalizeAadhaar(' 1234 5678 9012 '), '123456789012');
    });
  });
}

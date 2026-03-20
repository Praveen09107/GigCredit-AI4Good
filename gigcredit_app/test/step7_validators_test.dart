import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step7_validators.dart';

void main() {
  group('Step7Validators', () {
    test('validatePolicyNumber accepts alphanumeric policy number', () {
      expect(Step7Validators.validatePolicyNumber('POL-123456'), isNull);
      expect(Step7Validators.validatePolicyNumber('ab12cd34'), isNull);
    });

    test('validatePolicyNumber rejects invalid policy number', () {
      expect(Step7Validators.validatePolicyNumber(''), isNotNull);
      expect(Step7Validators.validatePolicyNumber('A1-'), isNotNull);
      expect(Step7Validators.validatePolicyNumber('POL@1234'), isNotNull);
    });

    test('validateHolderName enforces non-empty and minimum length', () {
      expect(Step7Validators.validateHolderName('Praveen Kumar'), isNull);
      expect(Step7Validators.validateHolderName(''), isNotNull);
      expect(Step7Validators.validateHolderName('AB'), isNotNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step3_validators.dart';

void main() {
  group('Step3Validators', () {
    test('validateIfsc accepts valid IFSC', () {
      expect(Step3Validators.validateIfsc('HDFC0001234'), isNull);
      expect(Step3Validators.validateIfsc('hdfc0001234'), isNull);
    });

    test('validateIfsc rejects invalid IFSC', () {
      expect(Step3Validators.validateIfsc('HDFC001234'), isNotNull);
      expect(Step3Validators.validateIfsc('ABCD01234'), isNotNull);
      expect(Step3Validators.validateIfsc('12340001234'), isNotNull);
    });

    test('validateAccountNumber enforces 9 to 18 digits', () {
      expect(Step3Validators.validateAccountNumber('123456789'), isNull);
      expect(Step3Validators.validateAccountNumber('123456789012345678'), isNull);
      expect(Step3Validators.validateAccountNumber('12345678'), isNotNull);
      expect(Step3Validators.validateAccountNumber('1234567890123456789'), isNotNull);
      expect(Step3Validators.validateAccountNumber('12A456789'), isNotNull);
    });

    test('normalizers format IFSC and account number', () {
      expect(Step3Validators.normalizeIfsc(' hdfc0001234 '), 'HDFC0001234');
      expect(Step3Validators.normalizeAccountNumber(' 1234567890 '), '1234567890');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step4_validators.dart';

void main() {
  group('Step4Validators', () {
    test('validateSixMonthCount enforces minimum upload count', () {
      expect(
        Step4Validators.validateSixMonthCount(count: 6, utilityName: 'Electricity'),
        isNull,
      );
      expect(
        Step4Validators.validateSixMonthCount(count: 5, utilityName: 'Electricity'),
        isNotNull,
      );
    });

    test('isSameIdentifierAcrossBills checks case-insensitive consistency', () {
      expect(Step4Validators.isSameIdentifierAcrossBills([]), isFalse);
      expect(
        Step4Validators.isSameIdentifierAcrossBills(['EB123', 'eb123', ' Eb123 ']),
        isTrue,
      );
      expect(
        Step4Validators.isSameIdentifierAcrossBills(['EB123', 'EB124']),
        isFalse,
      );
    });

    test('looksNumericAmount accepts numeric and decimal amounts', () {
      expect(Step4Validators.looksNumericAmount('100'), isTrue);
      expect(Step4Validators.looksNumericAmount('100.5'), isTrue);
      expect(Step4Validators.looksNumericAmount('100.50'), isTrue);
      expect(Step4Validators.looksNumericAmount('100.500'), isFalse);
      expect(Step4Validators.looksNumericAmount('10a.50'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step8_validators.dart';

void main() {
  group('Step8Validators', () {
    test('validatePan accepts and rejects expected formats', () {
      expect(Step8Validators.validatePan('ABCDE1234F'), isNull);
      expect(Step8Validators.validatePan('abcde1234f'), isNull);
      expect(Step8Validators.validatePan('ABCD1234F'), isNotNull);
      expect(Step8Validators.validatePan('ABCDE12345'), isNotNull);
    });

    test('validateAnnualIncome enforces positive numeric value', () {
      expect(Step8Validators.validateAnnualIncome('250000'), isNull);
      expect(Step8Validators.validateAnnualIncome('250000.50'), isNull);
      expect(Step8Validators.validateAnnualIncome('0'), isNotNull);
      expect(Step8Validators.validateAnnualIncome('-1'), isNotNull);
      expect(Step8Validators.validateAnnualIncome('abc'), isNotNull);
    });

    test('withinFortyPercentTolerance checks expected range', () {
      expect(
        Step8Validators.withinFortyPercentTolerance(observed: 100, baseline: 0),
        isTrue,
      );
      expect(
        Step8Validators.withinFortyPercentTolerance(observed: 70, baseline: 100),
        isTrue,
      );
      expect(
        Step8Validators.withinFortyPercentTolerance(observed: 140, baseline: 100),
        isTrue,
      );
      expect(
        Step8Validators.withinFortyPercentTolerance(observed: 59, baseline: 100),
        isFalse,
      );
      expect(
        Step8Validators.withinFortyPercentTolerance(observed: 141, baseline: 100),
        isFalse,
      );
    });
  });
}

import 'package:gigcredit_app/core/validation/step1_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Step-1 validators and normalization', () {
    expect(Step1Validators.validateFullName('Praveen Kumar'), isNull);
    expect(Step1Validators.validateFullName('P1'), isNotNull);

    expect(Step1Validators.validateAge('28'), isNull);
    expect(Step1Validators.validateAge('17'), isNotNull);
    expect(Step1Validators.validateDateOfBirth('12/06/1997'), isNull);
    expect(Step1Validators.validateDateOfBirth('1997-06-12'), isNotNull);

    expect(Step1Validators.validateMobile('9876543210'), isNull);
    expect(Step1Validators.validateMobile('1234567890'), isNotNull);

    expect(Step1Validators.validateStateOfResidence('Tamil Nadu'), isNull);
    expect(Step1Validators.validateMonthlyIncome('22000'), isNull);
    expect(Step1Validators.validateYearsInCurrentProfession('3'), isNull);
    expect(Step1Validators.validateDependents('2'), isNull);

    expect(Step1Validators.normalizeName('  Praveen  K.  '), 'PRAVEEN K');
    expect(Step1Validators.normalizeAddress('  12, MG  Road   Chennai '), '12, mg road chennai');
  });
}

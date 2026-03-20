import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/core/validation/step6_validators.dart';

void main() {
  group('Step6Validators', () {
    test('accepts empty optional references', () {
      expect(Step6Validators.validatePmSymRef(''), isNull);
      expect(Step6Validators.validatePmjjbyRef('  '), isNull);
      expect(Step6Validators.validatePpfAccountRef(''), isNull);
    });

    test('rejects malformed optional references', () {
      expect(Step6Validators.validatePmSymRef('pm'), isNotNull);
      expect(Step6Validators.validatePmjjbyRef('@@@###'), isNotNull);
      expect(Step6Validators.validatePpfAccountRef('12'), isNotNull);
    });

    test('accepts normalized optional references', () {
      expect(Step6Validators.validatePmSymRef('PMSYM-778899'), isNull);
      expect(Step6Validators.validatePmjjbyRef('PMJJBY5566'), isNull);
      expect(Step6Validators.validatePpfAccountRef('PPF-00123456'), isNull);
    });
  });
}

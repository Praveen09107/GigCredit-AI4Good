import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/models/enums/step_status.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/scoring/feature_sanitizer.dart';

void main() {
  group('Core smoke tests', () {
    test('sanitizeFeatures clamps values and preserves expected length', () {
      final sanitized = sanitizeFeatures(<double>[double.nan, -1.0, 0.25, 1.5], expectedLength: 6);

      expect(sanitized, hasLength(6));
      expect(sanitized[0], 0.5);
      expect(sanitized[1], 0.0);
      expect(sanitized[2], 0.25);
      expect(sanitized[3], 1.0);
      expect(sanitized[4], 0.5);
      expect(sanitized[5], 0.5);
    });

    test('VerifiedProfile JSON round-trip keeps core fields', () {
      final profile = VerifiedProfile.initial().copyWith(
        fullName: 'Test User',
        phoneNumber: '9999999999',
        monthlyIncome: 22000,
        workType: WorkType.vendor,
        minimumGatePassed: true,
        currentStep: StepId.step3Bank,
        verificationState: {
          for (final step in StepId.values) step: StepStatus.inProgress,
        },
        featureVector: List<double>.filled(95, 0.8),
      );

      final restored = VerifiedProfile.fromJson(profile.toJson());

      expect(restored.fullName, profile.fullName);
      expect(restored.phoneNumber, profile.phoneNumber);
      expect(restored.monthlyIncome, profile.monthlyIncome);
      expect(restored.workType, profile.workType);
      expect(restored.minimumGatePassed, profile.minimumGatePassed);
      expect(restored.currentStep, profile.currentStep);
      expect(restored.featureVector, hasLength(95));
      expect(restored.featureVector.first, 0.8);
      expect(restored.verificationState.length, StepId.values.length);
    });
  });
}
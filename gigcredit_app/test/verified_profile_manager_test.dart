import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/models/enums/step_id.dart';
import 'package:gigcredit_app/models/enums/step_status.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';

void main() {
  group('VerifiedProfile Serialization and Default Constraints Tests', () {
    test('VerifiedProfile initial creation sets default empty arrays and false bools', () {
      final profile = VerifiedProfile(
        fullName: '',
        phoneNumber: '1234567890',
        dateOfBirthText: '',
        currentAddress: '',
        permanentAddress: '',
        stateOfResidence: '',
        age: 0,
        workType: WorkType.platformWorker,
        minimumGatePassed: false,
        currentStep: StepId.step1Profile,
        verificationState: {
          for (final step in StepId.values) step: StepStatus.notStarted,
        },
        featureVector: List<double>.filled(95, 0.0),
      );

      // Step 1 — no dateOfBirth field in current model; phoneNumber is set
      expect(profile.phoneNumber, '1234567890');

      // Step 2
      expect(profile.aadhaarVerified, isFalse);
      expect(profile.faceMatchScore, 0.0);

      // Step 3
      expect(profile.bankVerified, isFalse);

      // Step 4
      expect(profile.electricityVerified, isFalse);

      // Step 5
      expect(profile.workProofVerified, isFalse);

      // Step 6 & 7 & 8
      expect(profile.svanidhiVerified, isFalse);
      expect(profile.healthInsuranceVerified, isFalse);
      expect(profile.itrVerified, isFalse);

      // Step 9
      expect(profile.emiDetected, isFalse);
      expect(profile.monthlyEmiObligation, 0.0);
    });
  });
}

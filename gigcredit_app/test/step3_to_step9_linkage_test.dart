import 'package:gigcredit_app/core/session/secure_storage.dart';
import 'package:gigcredit_app/models/enums/step_id.dart';
import 'package:gigcredit_app/models/enums/step_status.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/state/verified_profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/models/verified_profile.dart';

class MockSecureStorage implements SecureStorage {
  const MockSecureStorage();
  @override
  Future<void> saveProfile(VerifiedProfile profile) async {}
  @override
  Future<VerifiedProfile?> readProfile() async => null;
  @override
  Future<void> clearProfile() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Integration: Step-3 to Step-9 linkage behavior', () {
    final notifier = VerifiedProfileNotifier(const MockSecureStorage());

    notifier.completeStep1(
      fullName: 'Asha Devi',
      dateOfBirthText: '01/02/1991',
      mobile: '9988776655',
      currentAddress: '44 Market Street Madurai 625001',
      permanentAddress: '44 Market Street Madurai 625001',
      stateOfResidence: 'Tamil Nadu',
      workType: WorkType.vendor,
      monthlyIncomeText: '28000',
      yearsInCurrentProfessionText: '6',
      numberOfDependentsText: '1',
      hasVehicle: false,
      secondaryIncomeSource: 'Part-time stitching',
      secondaryIncomeAmountText: '3000',
    );

    final s2 = notifier.completeStep2(
      aadhaarNumber: '999988887777',
      panNumber: 'PQRSX1234Z',
      faceMatchScore: 0.87,
    );
    expect(s2, isTrue);

    final now = DateTime.now();
    final s3 = notifier.completeStep3(
      bankName: 'HDFC',
      accountHolderName: 'Asha Devi',
      ifscCode: 'HDFC0001234',
      accountNumber: '445566778899',
      statementFrom: now.subtract(const Duration(days: 190)),
      statementTo: now.subtract(const Duration(days: 8)),
      transactionCount: 72,
      emiCandidateCount: 1,
      monthlyEmiObligation: 5000,
    );
    expect(s3, isTrue);

    // After step 3, step9 should still be notStarted (not automatically inProgress)
    expect(
      notifier.state.verificationState[StepId.step9EmiLoan],
      StepStatus.notStarted,
    );

    final s4 = notifier.completeStep4(
      electricityVerified: true,
      lpgVerified: true,
      mobileVerified: true,
      rentVerified: true,
      wifiVerified: false,
      ottVerified: false,
    );
    expect(s4, isTrue);

    final s5 = notifier.completeStep5(
      workProofProvided: true,
      workProofVerified: true,
      vehicleOwnerMismatch: false,
    );
    expect(s5, isTrue);

    final s6 = notifier.completeStep6(
      selectedSvanidhi: true,
      selectedEShram: false,
      selectedPmSym: false,
      selectedPmjjby: false,
      selectedUdyam: false,
      selectedPpf: false,
      svanidhiVerified: true,
      eShramVerified: false,
      pmSymVerified: false,
      pmjjbyVerified: false,
      udyamVerified: false,
      ppfVerified: false,
    );
    expect(s6, isTrue);

    final s7 = notifier.completeStep7(
      selectedHealthInsurance: true,
      selectedLifeInsurance: false,
      selectedVehicleInsurance: false,
      healthInsuranceVerified: true,
      lifeInsuranceVerified: false,
      vehicleInsuranceVerified: false,
    );
    expect(s7, isTrue);

    final s8 = notifier.completeStep8(
      selectedItr: true,
      selectedGst: false,
      itrVerified: true,
      gstVerified: false,
      itrAnnualIncome: 360000,
      gstAnnualIncome: 0,
    );
    expect(s8, isTrue);

    // Still not verified yet
    expect(
      notifier.state.verificationState[StepId.step9EmiLoan],
      StepStatus.notStarted,
    );

    final s9 = notifier.completeStep9(
      emiCandidateCount: 1,
      monthlyEmiObligation: 6500,
      estimatedMonthlyIncome: 30000,
      debtToIncomeRatio: 0.216,
      emiRiskBand: 'MEDIUM',
      loanVerificationAttempted: true,
      loanVerificationPassed: true,
    );
    expect(s9, isTrue);

    expect(notifier.state.emiRiskBand, 'MEDIUM');
    expect(notifier.state.monthlyEmiObligation, 6500);
  });
}

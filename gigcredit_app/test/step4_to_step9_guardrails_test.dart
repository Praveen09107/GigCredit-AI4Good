import 'package:flutter_test/flutter_test.dart';

import 'package:gigcredit_app/core/session/secure_storage.dart';
import 'package:gigcredit_app/models/enums/step_status.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/state/verified_profile_provider.dart';

class _MockSecureStorage implements SecureStorage {
  const _MockSecureStorage();

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
  VerifiedProfileNotifier buildNotifier() {
    return VerifiedProfileNotifier(const _MockSecureStorage());
  }

  void completeUntilStep3(VerifiedProfileNotifier notifier) {
    notifier.completeStep1(
      fullName: 'Praveen Kumar',
      dateOfBirthText: '12/06/1995',
      mobile: '9876543210',
      currentAddress: '12 MG Road Chennai 600001',
      permanentAddress: '12 MG Road Chennai 600001',
      stateOfResidence: 'Tamil Nadu',
      workType: WorkType.platformWorker,
      monthlyIncomeText: '30000',
      yearsInCurrentProfessionText: '4',
      numberOfDependentsText: '2',
      hasVehicle: true,
      secondaryIncomeSource: '',
      secondaryIncomeAmountText: '',
    );

    final s2 = notifier.completeStep2(
      aadhaarNumber: '123412341234',
      panNumber: 'ABCDE1234F',
      faceMatchScore: 0.91,
    );
    expect(s2, isTrue);

    final now = DateTime.now();
    final s3 = notifier.completeStep3(
      bankName: 'SBI',
      accountHolderName: 'Praveen Kumar',
      ifscCode: 'SBIN0001234',
      accountNumber: '123456789012',
      statementFrom: now.subtract(const Duration(days: 200)),
      statementTo: now.subtract(const Duration(days: 10)),
      transactionCount: 88,
      emiCandidateCount: 2,
      monthlyEmiObligation: 3000,
    );
    expect(s3, isTrue);
  }

  void completeUntilStep8(VerifiedProfileNotifier notifier) {
    completeUntilStep3(notifier);
    expect(
      notifier.completeStep4(
        electricityVerified: true,
        lpgVerified: true,
        mobileVerified: true,
        rentVerified: false,
        wifiVerified: false,
        ottVerified: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep5(
        workProofProvided: false,
        workProofVerified: false,
        vehicleOwnerMismatch: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep6(
        selectedSvanidhi: false,
        selectedEShram: false,
        selectedPmSym: false,
        selectedPmjjby: false,
        selectedUdyam: false,
        selectedPpf: false,
        svanidhiVerified: false,
        eShramVerified: false,
        pmSymVerified: false,
        pmjjbyVerified: false,
        udyamVerified: false,
        ppfVerified: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep7(
        selectedHealthInsurance: false,
        selectedLifeInsurance: false,
        selectedVehicleInsurance: true,
        healthInsuranceVerified: false,
        lifeInsuranceVerified: false,
        vehicleInsuranceVerified: true,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep8(
        selectedItr: false,
        selectedGst: false,
        itrVerified: false,
        gstVerified: false,
        itrAnnualIncome: 0,
        gstAnnualIncome: 0,
      ),
      isTrue,
    );
  }

  test('Step 4 rejects completion before Step 3 is verified', () {
    final notifier = buildNotifier();

    notifier.completeStep1(
      fullName: 'Praveen Kumar',
      dateOfBirthText: '12/06/1995',
      mobile: '9876543210',
      currentAddress: '12 MG Road Chennai 600001',
      permanentAddress: '12 MG Road Chennai 600001',
      stateOfResidence: 'Tamil Nadu',
      workType: WorkType.platformWorker,
      monthlyIncomeText: '30000',
      yearsInCurrentProfessionText: '4',
      numberOfDependentsText: '2',
      hasVehicle: true,
      secondaryIncomeSource: '',
      secondaryIncomeAmountText: '',
    );

    final ok = notifier.completeStep4(
      electricityVerified: true,
      lpgVerified: true,
      mobileVerified: true,
      rentVerified: false,
      wifiVerified: false,
      ottVerified: false,
    );

    expect(ok, isFalse);
    expect(notifier.state.currentStep, StepId.step2Kyc);
    expect(notifier.state.verificationState[StepId.step4Utilities], isNot(StepStatus.verified));
  });

  test('Step 5 rejects inconsistent provided/verified combination', () {
    final notifier = buildNotifier();
    completeUntilStep3(notifier);
    expect(
      notifier.completeStep4(
        electricityVerified: true,
        lpgVerified: true,
        mobileVerified: true,
        rentVerified: false,
        wifiVerified: false,
        ottVerified: false,
      ),
      isTrue,
    );

    final ok = notifier.completeStep5(
      workProofProvided: true,
      workProofVerified: false,
      vehicleOwnerMismatch: false,
    );

    expect(ok, isFalse);
    expect(notifier.state.currentStep, StepId.step5WorkProof);
  });

  test('Step 6 rejects selected scheme when verification is false', () {
    final notifier = buildNotifier();
    completeUntilStep3(notifier);
    expect(
      notifier.completeStep4(
        electricityVerified: true,
        lpgVerified: true,
        mobileVerified: true,
        rentVerified: false,
        wifiVerified: false,
        ottVerified: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep5(
        workProofProvided: false,
        workProofVerified: false,
        vehicleOwnerMismatch: false,
      ),
      isTrue,
    );

    final ok = notifier.completeStep6(
      selectedSvanidhi: true,
      selectedEShram: false,
      selectedPmSym: false,
      selectedPmjjby: false,
      selectedUdyam: false,
      selectedPpf: false,
      svanidhiVerified: false,
      eShramVerified: false,
      pmSymVerified: false,
      pmjjbyVerified: false,
      udyamVerified: false,
      ppfVerified: false,
    );

    expect(ok, isFalse);
    expect(notifier.state.currentStep, StepId.step6Schemes);
  });

  test('Step 7 requires vehicle insurance when hasVehicle is true', () {
    final notifier = buildNotifier();
    completeUntilStep3(notifier);
    expect(
      notifier.completeStep4(
        electricityVerified: true,
        lpgVerified: true,
        mobileVerified: true,
        rentVerified: false,
        wifiVerified: false,
        ottVerified: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep5(
        workProofProvided: false,
        workProofVerified: false,
        vehicleOwnerMismatch: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep6(
        selectedSvanidhi: false,
        selectedEShram: false,
        selectedPmSym: false,
        selectedPmjjby: false,
        selectedUdyam: false,
        selectedPpf: false,
        svanidhiVerified: false,
        eShramVerified: false,
        pmSymVerified: false,
        pmjjbyVerified: false,
        udyamVerified: false,
        ppfVerified: false,
      ),
      isTrue,
    );

    final ok = notifier.completeStep7(
      selectedHealthInsurance: false,
      selectedLifeInsurance: false,
      selectedVehicleInsurance: false,
      healthInsuranceVerified: false,
      lifeInsuranceVerified: false,
      vehicleInsuranceVerified: false,
    );

    expect(ok, isFalse);
    expect(notifier.state.currentStep, StepId.step7Insurance);
  });

  test('Step 8 rejects selected ITR/GST with missing positive annual income', () {
    final notifier = buildNotifier();
    completeUntilStep3(notifier);
    expect(
      notifier.completeStep4(
        electricityVerified: true,
        lpgVerified: true,
        mobileVerified: true,
        rentVerified: false,
        wifiVerified: false,
        ottVerified: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep5(
        workProofProvided: false,
        workProofVerified: false,
        vehicleOwnerMismatch: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep6(
        selectedSvanidhi: false,
        selectedEShram: false,
        selectedPmSym: false,
        selectedPmjjby: false,
        selectedUdyam: false,
        selectedPpf: false,
        svanidhiVerified: false,
        eShramVerified: false,
        pmSymVerified: false,
        pmjjbyVerified: false,
        udyamVerified: false,
        ppfVerified: false,
      ),
      isTrue,
    );
    expect(
      notifier.completeStep7(
        selectedHealthInsurance: false,
        selectedLifeInsurance: false,
        selectedVehicleInsurance: true,
        healthInsuranceVerified: false,
        lifeInsuranceVerified: false,
        vehicleInsuranceVerified: true,
      ),
      isTrue,
    );

    final ok = notifier.completeStep8(
      selectedItr: true,
      selectedGst: false,
      itrVerified: true,
      gstVerified: false,
      itrAnnualIncome: 0,
      gstAnnualIncome: 0,
    );

    expect(ok, isFalse);
    expect(notifier.state.currentStep, StepId.step8ItrGst);
  });

  test('Step 9 rejects invalid risk band and passed-without-attempt state', () {
    final notifier = buildNotifier();
    completeUntilStep8(notifier);

    final invalidRisk = notifier.completeStep9(
      emiCandidateCount: 1,
      monthlyEmiObligation: 3000,
      estimatedMonthlyIncome: 25000,
      debtToIncomeRatio: 0.12,
      emiRiskBand: 'CRITICAL',
      loanVerificationAttempted: true,
      loanVerificationPassed: true,
    );
    expect(invalidRisk, isFalse);

    final inconsistentVerification = notifier.completeStep9(
      emiCandidateCount: 1,
      monthlyEmiObligation: 3000,
      estimatedMonthlyIncome: 25000,
      debtToIncomeRatio: 0.12,
      emiRiskBand: 'LOW',
      loanVerificationAttempted: false,
      loanVerificationPassed: true,
    );
    expect(inconsistentVerification, isFalse);
  });
}
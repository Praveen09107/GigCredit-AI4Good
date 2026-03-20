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
  test('Integration: 9-step progression completes', () {
    final secureStorage = const MockSecureStorage();
    final notifier = VerifiedProfileNotifier(secureStorage);

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
    // Check using verificationState map
    expect(
      notifier.state.verificationState[StepId.step1Profile],
      StepStatus.verified,
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

    final s4 = notifier.completeStep4(
      electricityVerified: true,
      lpgVerified: true,
      mobileVerified: true,
      rentVerified: false,
      wifiVerified: false,
      ottVerified: false,
    );
    expect(s4, isTrue);

    final s5 = notifier.completeStep5(
      workProofProvided: false,
      workProofVerified: false,
      vehicleOwnerMismatch: false,
    );
    expect(s5, isTrue);

    final s6 = notifier.completeStep6(
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
    );
    expect(s6, isTrue);

    final s7 = notifier.completeStep7(
      selectedHealthInsurance: false,
      selectedLifeInsurance: false,
      selectedVehicleInsurance: true,
      healthInsuranceVerified: false,
      lifeInsuranceVerified: false,
      vehicleInsuranceVerified: true,
    );
    expect(s7, isTrue);

    final s8 = notifier.completeStep8(
      selectedItr: false,
      selectedGst: false,
      itrVerified: false,
      gstVerified: false,
      itrAnnualIncome: 0,
      gstAnnualIncome: 0,
    );
    expect(s8, isTrue);

    final s9 = notifier.completeStep9(
      emiCandidateCount: 2,
      monthlyEmiObligation: 4500,
      estimatedMonthlyIncome: 30000,
      debtToIncomeRatio: 0.15,
      emiRiskBand: 'LOW',
      loanVerificationAttempted: true,
      loanVerificationPassed: true,
    );
    expect(s9, isTrue);

    expect(
      notifier.state.verificationState[StepId.step9EmiLoan],
      StepStatus.verified,
    );
  });
}

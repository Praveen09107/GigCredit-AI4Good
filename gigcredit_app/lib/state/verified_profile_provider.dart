import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/verified_profile.dart';
import '../models/enums/step_status.dart';
import '../models/enums/work_type.dart';
import '../core/session/secure_storage.dart';
import '../core/validation/step1_validators.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => const SecureStorage());

class VerifiedProfileNotifier extends StateNotifier<VerifiedProfile> {
    VerifiedProfileNotifier(this._secureStorage) : super(VerifiedProfile.initial()) {
        _restore();
    }

    final SecureStorage _secureStorage;

    Future<void> _restore() async {
        final saved = await _secureStorage.readProfile();
        if (saved != null) {
            state = saved;
        }
    }

    void restoreState(VerifiedProfile p) {
        state = p;
        _secureStorage.saveProfile(state);
    }

    bool completeStep1({
        required String fullName,
        required String dateOfBirthText,
        required String mobile,
        required String currentAddress,
        required String permanentAddress,
        required String stateOfResidence,
        required WorkType workType,
        required String monthlyIncomeText,
        required String yearsInCurrentProfessionText,
        required String numberOfDependentsText,
        required bool hasVehicle,
        required String secondaryIncomeSource,
        required String secondaryIncomeAmountText,
    }) {
        final dob = Step1Validators.parseDob(dateOfBirthText.trim());
        final age = dob == null ? 0 : Step1Validators.calculateAgeFromDob(dob);
        final income = double.tryParse(monthlyIncomeText) ?? 0.0;
        final secondaryIncome = double.tryParse(secondaryIncomeAmountText) ?? 0.0;
        final yearsProf = int.tryParse(yearsInCurrentProfessionText) ?? 0;
        final deps = int.tryParse(numberOfDependentsText) ?? 0;

        state = state.copyWith(
            fullName: fullName,
            phoneNumber: mobile,
            dateOfBirthText: dateOfBirthText.trim(),
            currentAddress: currentAddress.trim(),
            permanentAddress: permanentAddress.trim(),
            stateOfResidence: stateOfResidence.trim(),
            selfDeclaredMonthlyIncome: income,
            monthlyIncome: income,
            secondaryIncomeAmount: secondaryIncome,
            yearsInCurrentProfession: yearsProf,
            numberOfDependents: deps,
            hasVehicle: hasVehicle,
            workType: workType,
            age: age,
            verificationState: {
                ...state.verificationState,
                StepId.step1Profile: StepStatus.verified,
            },
            currentStep: StepId.step2Kyc,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep2({
        required String aadhaarNumber,
        required String panNumber,
        required double faceMatchScore,
    }) {
        state = state.copyWith(
            aadhaarNumber: aadhaarNumber.trim(),
            panNumber: panNumber.trim().toUpperCase(),
            faceMatchScore: faceMatchScore,
            aadhaarVerified: true,
            panVerified: true,
            faceVerified: true,
            verificationState: {
                ...state.verificationState,
                StepId.step2Kyc: StepStatus.verified,
            },
            currentStep: StepId.step3Bank,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep3({
        required String bankName,
        required String ifscCode,
        String accountNumberMasked = '',
        String accountHolderName = '',
        String accountNumber = '',
        required int transactionCount,
        double estimatedMonthlyIncome = 0.0,
        required DateTime statementFrom,
        required DateTime statementTo,
        bool emiDetected = false,
        required int emiCandidateCount,
        required double monthlyEmiObligation,
    }) {
        final normalizedHolder = _normalizeIdentityText(accountHolderName);
        final normalizedProfileName = _normalizeIdentityText(state.fullName);
        if (normalizedHolder.isEmpty || normalizedProfileName.isEmpty || normalizedHolder != normalizedProfileName) {
            return false;
        }
        final gatePassed = transactionCount >= 30 && state.aadhaarVerified && state.panVerified;
        final normalizedAccount = accountNumber.trim();
        final derivedMasked = accountNumberMasked.trim().isNotEmpty
            ? accountNumberMasked.trim()
            : (normalizedAccount.length > 4
                ? 'XXXXXX${normalizedAccount.substring(normalizedAccount.length - 4)}'
                : normalizedAccount);
        state = state.copyWith(
            ifscCode: ifscCode.trim().toUpperCase(),
            accountNumberMasked: derivedMasked,
            transactionCount: transactionCount,
            estimatedMonthlyIncome: estimatedMonthlyIncome,
            statementFrom: statementFrom,
            statementTo: statementTo,
            emiDetected: emiDetected,
            emiCandidateCount: emiCandidateCount,
            monthlyEmiObligation: monthlyEmiObligation,
            minimumGatePassed: gatePassed,
            bankVerified: true,
            verificationState: {
                ...state.verificationState,
                StepId.step3Bank: StepStatus.verified,
            },
            currentStep: StepId.step4Utilities,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    String _normalizeIdentityText(String value) {
        final stripped = value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), ' ');
        return stripped.replaceAll(RegExp(r'\s+'), ' ');
    }

    bool completeStep4({
        required bool electricityVerified,
        required bool lpgVerified,
        bool mobileVerified = false,
        bool mobileUtilityVerified = false,
        required bool rentVerified,
        required bool wifiVerified,
        required bool ottVerified,
    }) {
        if (state.verificationState[StepId.step3Bank] != StepStatus.verified) {
            return false;
        }

        final mobileOk = mobileUtilityVerified || mobileVerified;
        if (!(electricityVerified && lpgVerified && mobileOk)) {
            return false;
        }

        state = state.copyWith(
            electricityVerified: electricityVerified,
            lpgVerified: lpgVerified,
            mobileUtilityVerified: mobileOk,
            rentVerified: rentVerified,
            wifiVerified: wifiVerified,
            ottVerified: ottVerified,
            verificationState: {
                ...state.verificationState,
                StepId.step4Utilities: StepStatus.verified,
            },
            currentStep: StepId.step5WorkProof,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep5({
        required bool workProofVerified,
        required bool workProofProvided,
        required bool vehicleOwnerMismatch,
    }) {
        if (state.verificationState[StepId.step4Utilities] != StepStatus.verified) {
            return false;
        }

        if (workProofProvided && !workProofVerified) {
            return false;
        }

        state = state.copyWith(
            workProofVerified: workProofVerified,
            workProofProvided: workProofProvided,
            vehicleOwnerMismatch: vehicleOwnerMismatch,
            verificationState: {
                ...state.verificationState,
                StepId.step5WorkProof: StepStatus.verified,
            },
            currentStep: StepId.step6Schemes,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep6({
        required bool selectedSvanidhi,
        required bool selectedEShram,
        required bool selectedPmSym,
        required bool selectedPmjjby,
        required bool selectedUdyam,
        required bool selectedPpf,
        required bool svanidhiVerified,
        required bool eShramVerified,
        required bool pmSymVerified,
        required bool pmjjbyVerified,
        required bool udyamVerified,
        required bool ppfVerified,
    }) {
        if (state.verificationState[StepId.step5WorkProof] != StepStatus.verified) {
            return false;
        }

        if ((selectedSvanidhi && !svanidhiVerified) ||
            (selectedEShram && !eShramVerified) ||
            (selectedPmSym && !pmSymVerified) ||
            (selectedPmjjby && !pmjjbyVerified) ||
            (selectedUdyam && !udyamVerified) ||
            (selectedPpf && !ppfVerified)) {
            return false;
        }

        state = state.copyWith(
            selectedSvanidhi: selectedSvanidhi,
            selectedEShram: selectedEShram,
            selectedPmSym: selectedPmSym,
            selectedPmjjby: selectedPmjjby,
            selectedUdyam: selectedUdyam,
            selectedPpf: selectedPpf,
            svanidhiVerified: svanidhiVerified,
            eShramVerified: eShramVerified,
            pmSymVerified: pmSymVerified,
            pmjjbyVerified: pmjjbyVerified,
            udyamVerified: udyamVerified,
            ppfVerified: ppfVerified,
            verificationState: {
                ...state.verificationState,
                StepId.step6Schemes: StepStatus.verified,
            },
            currentStep: StepId.step7Insurance,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep7({
        required bool selectedHealthInsurance,
        required bool selectedLifeInsurance,
        required bool selectedVehicleInsurance,
        required bool healthInsuranceVerified,
        required bool lifeInsuranceVerified,
        required bool vehicleInsuranceVerified,
    }) {
        if (state.verificationState[StepId.step6Schemes] != StepStatus.verified) {
            return false;
        }

        if ((selectedHealthInsurance && !healthInsuranceVerified) ||
            (selectedLifeInsurance && !lifeInsuranceVerified) ||
            (selectedVehicleInsurance && !vehicleInsuranceVerified)) {
            return false;
        }

        if (state.hasVehicle && !selectedVehicleInsurance) {
            return false;
        }

        state = state.copyWith(
            selectedHealthInsurance: selectedHealthInsurance,
            selectedLifeInsurance: selectedLifeInsurance,
            selectedVehicleInsurance: selectedVehicleInsurance,
            healthInsuranceVerified: healthInsuranceVerified,
            lifeInsuranceVerified: lifeInsuranceVerified,
            vehicleInsuranceVerified: vehicleInsuranceVerified,
            verificationState: {
                ...state.verificationState,
                StepId.step7Insurance: StepStatus.verified,
            },
            currentStep: StepId.step8ItrGst,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep8({
        required bool selectedItr,
        required bool selectedGst,
        required bool itrVerified,
        required bool gstVerified,
        required double itrAnnualIncome,
        required double gstAnnualIncome,
    }) {
        if (state.verificationState[StepId.step7Insurance] != StepStatus.verified) {
            return false;
        }

        if ((selectedItr && !itrVerified) || (selectedGst && !gstVerified)) {
            return false;
        }

        if ((selectedItr && itrAnnualIncome <= 0) || (selectedGst && gstAnnualIncome <= 0)) {
            return false;
        }

        if (itrAnnualIncome < 0 || gstAnnualIncome < 0) {
            return false;
        }

        state = state.copyWith(
            selectedItr: selectedItr,
            selectedGst: selectedGst,
            itrVerified: itrVerified,
            gstVerified: gstVerified,
            itrAnnualIncome: itrAnnualIncome,
            gstAnnualIncome: gstAnnualIncome,
            verificationState: {
                ...state.verificationState,
                StepId.step8ItrGst: StepStatus.verified,
            },
            currentStep: StepId.step9EmiLoan,
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    bool completeStep9({
        required int emiCandidateCount,
        required double monthlyEmiObligation,
        required double estimatedMonthlyIncome,
        required double debtToIncomeRatio,
        required String emiRiskBand,
        required bool loanVerificationAttempted,
        required bool loanVerificationPassed,
    }) {
        if (state.verificationState[StepId.step8ItrGst] != StepStatus.verified) {
            return false;
        }

        if (emiCandidateCount < 0 || monthlyEmiObligation < 0 || estimatedMonthlyIncome < 0 || debtToIncomeRatio < 0) {
            return false;
        }

        const allowedRiskBands = <String>{'LOW', 'MEDIUM', 'HIGH'};
        if (!allowedRiskBands.contains(emiRiskBand.toUpperCase())) {
            return false;
        }

        if (loanVerificationPassed && !loanVerificationAttempted) {
            return false;
        }

        state = state.copyWith(
            emiCandidateCount: emiCandidateCount,
            monthlyEmiObligation: monthlyEmiObligation,
            estimatedMonthlyIncome: estimatedMonthlyIncome,
            debtToIncomeRatio: debtToIncomeRatio,
            emiRiskBand: emiRiskBand,
            loanVerificationAttempted: loanVerificationAttempted,
            loanVerificationPassed: loanVerificationPassed,
            verificationState: {
                ...state.verificationState,
                StepId.step9EmiLoan: StepStatus.verified,
            },
            // final step, remains on step 9 conceptually
        );
        _secureStorage.saveProfile(state);
        return true;
    }

    Future<void> setMinimumGate(bool passed) async {
        state = state.copyWith(minimumGatePassed: passed);
        await _secureStorage.saveProfile(state);
    }

    Future<void> markStep(StepId stepId, StepStatus status) async {
        final next = {...state.verificationState, stepId: status};
        state = state.copyWith(verificationState: next, currentStep: stepId);
        await _secureStorage.saveProfile(state);
    }

    Future<void> regenerateFeatures() async {
        final incomeNorm = (state.selfDeclaredMonthlyIncome / 100000).clamp(0.05, 1.0);
        final workBoost = 0.04 * (state.workType?.metaIndex ?? 1);
        final vector = List<double>.generate(95, (index) {
            final harmonic = ((index % 10) / 10) * 0.18;
            final trend = (index / 95) * 0.12;
            final value = 0.30 + (incomeNorm * 0.42) + workBoost + harmonic + trend;
            return value.clamp(0.0, 1.0);
        });

        vector[36] = (0.70 - incomeNorm * 0.45).clamp(0.05, 0.95);

        state = state.copyWith(featureVector: vector);
        await _secureStorage.saveProfile(state);
    }

    Future<void> resetAll() async {
        state = VerifiedProfile.initial();
        await _secureStorage.clearProfile();
    }
}

final verifiedProfileProvider = StateNotifierProvider<VerifiedProfileNotifier, VerifiedProfile>((ref) {
    return VerifiedProfileNotifier(ref.read(secureStorageProvider));
});


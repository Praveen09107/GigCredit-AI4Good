import 'enums/step_status.dart';
import 'enums/work_type.dart';

/// GigCredit VerifiedProfile — full 95-feature contract model.
/// All fields required by feature_engineering.dart are present here.
/// Do NOT remove or rename any field — the feature vector indices are frozen.
class VerifiedProfile {
  const VerifiedProfile({
    // ── Core identity ─────────────────────────────────────────
    required this.fullName,
    required this.phoneNumber,
    required this.dateOfBirthText,
    required this.currentAddress,
    required this.permanentAddress,
    required this.stateOfResidence,
    required this.age,
    required this.workType,
    required this.currentStep,
    required this.verificationState,
    required this.featureVector,
    required this.minimumGatePassed,

    // ── P1: Identity verification ─────────────────────────────
    this.aadhaarVerified = false,
    this.panVerified = false,
    this.aadhaarNumber = '',
    this.panNumber = '',
    this.faceVerified = false,
    this.faceMatchScore = 0.0,
    this.hasVehicle = false,
    this.numberOfDependents = 0,

    // ── P2: Bank ──────────────────────────────────────────────
    this.bankVerified = false,
    this.transactionCount = 0,
    this.emiDetected = false,
    this.ifscCode = '',
    this.accountNumberMasked = '',
    this.estimatedMonthlyIncome = 0.0,
    this.selfDeclaredMonthlyIncome = 0.0,
    this.monthlyIncome = 0.0,         // alias for selfDeclaredMonthlyIncome
    this.monthlyEmiObligation = 0.0,
    this.debtToIncomeRatio = 0.0,
    this.emiCandidateCount = 0,
    this.secondaryIncomeAmount = 0.0,
    this.yearsInCurrentProfession = 0,
    this.vehicleOwnerMismatch = false,
    this.statementFrom,
    this.statementTo,

    // ── P3: Utility bills ─────────────────────────────────────
    this.electricityVerified = false,
    this.lpgVerified = false,
    this.mobileUtilityVerified = false,
    this.rentVerified = false,
    this.wifiVerified = false,
    this.ottVerified = false,

    // ── P4: Work proof ────────────────────────────────────────
    this.workProofProvided = false,
    this.workProofVerified = false,

    // ── P5: Government schemes ────────────────────────────────
    this.selectedSvanidhi = false,
    this.selectedEShram = false,
    this.selectedPmSym = false,
    this.selectedPmjjby = false,
    this.selectedUdyam = false,
    this.selectedPpf = false,
    this.svanidhiVerified = false,
    this.eShramVerified = false,
    this.pmSymVerified = false,
    this.pmjjbyVerified = false,
    this.udyamVerified = false,
    this.ppfVerified = false,

    // ── P6: Insurance ─────────────────────────────────────────
    this.selectedHealthInsurance = false,
    this.selectedLifeInsurance = false,
    this.selectedVehicleInsurance = false,
    this.healthInsuranceVerified = false,
    this.lifeInsuranceVerified = false,
    this.vehicleInsuranceVerified = false,

    // ── P7: Tax / GST ─────────────────────────────────────────
    this.selectedItr = false,
    this.selectedGst = false,
    this.itrVerified = false,
    this.gstVerified = false,
    this.itrAnnualIncome = 0.0,
    this.gstAnnualIncome = 0.0,

    // ── P8: EMI / Loan ────────────────────────────────────────
    this.loanVerificationAttempted = false,
    this.loanVerificationPassed = false,
    this.emiRiskBand = 'LOW',
  });

  // ── Factories ──────────────────────────────────────────────
  factory VerifiedProfile.initial() {
    return VerifiedProfile(
      fullName: '',
      phoneNumber: '',
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
  }

  // ── Core ──────────────────────────────────────────────────
  final String fullName;
  final String phoneNumber;
  final String dateOfBirthText;
  final String currentAddress;
  final String permanentAddress;
  final String stateOfResidence;
  final int age;
  final WorkType? workType;
  final bool minimumGatePassed;
  final StepId currentStep;
  final Map<StepId, StepStatus> verificationState;
  final List<double> featureVector;

  // ── P1: Identity ──────────────────────────────────────────
  final bool aadhaarVerified;
  final bool panVerified;
  final String aadhaarNumber;
  final String panNumber;
  final bool faceVerified;
  final double faceMatchScore;
  final bool hasVehicle;
  final int numberOfDependents;

  // ── P2: Bank ──────────────────────────────────────────────
  final bool bankVerified;
  final int transactionCount;
  final bool emiDetected;
  final String ifscCode;
  final String accountNumberMasked;
  final double estimatedMonthlyIncome;
  final double selfDeclaredMonthlyIncome;
  final double monthlyIncome;
  final double monthlyEmiObligation;
  final double debtToIncomeRatio;
  final int emiCandidateCount;
  final double secondaryIncomeAmount;
  final int yearsInCurrentProfession;
  final bool vehicleOwnerMismatch;
  final DateTime? statementFrom;
  final DateTime? statementTo;

  // ── P3: Utility ───────────────────────────────────────────
  final bool electricityVerified;
  final bool lpgVerified;
  final bool mobileUtilityVerified;
  final bool rentVerified;
  final bool wifiVerified;
  final bool ottVerified;

  // ── P4: Work Proof ────────────────────────────────────────
  final bool workProofProvided;
  final bool workProofVerified;

  // ── P5: Government Schemes ────────────────────────────────
  final bool selectedSvanidhi;
  final bool selectedEShram;
  final bool selectedPmSym;
  final bool selectedPmjjby;
  final bool selectedUdyam;
  final bool selectedPpf;
  final bool svanidhiVerified;
  final bool eShramVerified;
  final bool pmSymVerified;
  final bool pmjjbyVerified;
  final bool udyamVerified;
  final bool ppfVerified;

  // ── P6: Insurance ─────────────────────────────────────────
  final bool selectedHealthInsurance;
  final bool selectedLifeInsurance;
  final bool selectedVehicleInsurance;
  final bool healthInsuranceVerified;
  final bool lifeInsuranceVerified;
  final bool vehicleInsuranceVerified;

  // ── P7: Tax / GST ─────────────────────────────────────────
  final bool selectedItr;
  final bool selectedGst;
  final bool itrVerified;
  final bool gstVerified;
  final double itrAnnualIncome;
  final double gstAnnualIncome;

  // ── P8: EMI / Loan ────────────────────────────────────────
  final bool loanVerificationAttempted;
  final bool loanVerificationPassed;
  final String emiRiskBand;

  // ── copyWith ──────────────────────────────────────────────
  VerifiedProfile copyWith({
    String? fullName,
    String? phoneNumber,
    String? dateOfBirthText,
    String? currentAddress,
    String? permanentAddress,
    String? stateOfResidence,
    int? age,
    WorkType? workType,
    bool? minimumGatePassed,
    StepId? currentStep,
    Map<StepId, StepStatus>? verificationState,
    List<double>? featureVector,
    bool? aadhaarVerified,
    bool? panVerified,
    String? aadhaarNumber,
    String? panNumber,
    bool? faceVerified,
    double? faceMatchScore,
    bool? hasVehicle,
    int? numberOfDependents,
    bool? bankVerified,
    int? transactionCount,
    bool? emiDetected,
    String? ifscCode,
    String? accountNumberMasked,
    double? estimatedMonthlyIncome,
    double? selfDeclaredMonthlyIncome,
    double? monthlyIncome,
    double? monthlyEmiObligation,
    double? debtToIncomeRatio,
    int? emiCandidateCount,
    double? secondaryIncomeAmount,
    int? yearsInCurrentProfession,
    bool? vehicleOwnerMismatch,
    DateTime? statementFrom,
    DateTime? statementTo,
    bool? electricityVerified,
    bool? lpgVerified,
    bool? mobileUtilityVerified,
    bool? rentVerified,
    bool? wifiVerified,
    bool? ottVerified,
    bool? workProofProvided,
    bool? workProofVerified,
    bool? selectedSvanidhi,
    bool? selectedEShram,
    bool? selectedPmSym,
    bool? selectedPmjjby,
    bool? selectedUdyam,
    bool? selectedPpf,
    bool? svanidhiVerified,
    bool? eShramVerified,
    bool? pmSymVerified,
    bool? pmjjbyVerified,
    bool? udyamVerified,
    bool? ppfVerified,
    bool? selectedHealthInsurance,
    bool? selectedLifeInsurance,
    bool? selectedVehicleInsurance,
    bool? healthInsuranceVerified,
    bool? lifeInsuranceVerified,
    bool? vehicleInsuranceVerified,
    bool? selectedItr,
    bool? selectedGst,
    bool? itrVerified,
    bool? gstVerified,
    double? itrAnnualIncome,
    double? gstAnnualIncome,
    bool? loanVerificationAttempted,
    bool? loanVerificationPassed,
    String? emiRiskBand,
  }) {
    return VerifiedProfile(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirthText: dateOfBirthText ?? this.dateOfBirthText,
      currentAddress: currentAddress ?? this.currentAddress,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      stateOfResidence: stateOfResidence ?? this.stateOfResidence,
      age: age ?? this.age,
      workType: workType ?? this.workType,
      minimumGatePassed: minimumGatePassed ?? this.minimumGatePassed,
      currentStep: currentStep ?? this.currentStep,
      verificationState: verificationState ?? this.verificationState,
      featureVector: featureVector ?? this.featureVector,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      panVerified: panVerified ?? this.panVerified,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      panNumber: panNumber ?? this.panNumber,
      faceVerified: faceVerified ?? this.faceVerified,
      faceMatchScore: faceMatchScore ?? this.faceMatchScore,
      hasVehicle: hasVehicle ?? this.hasVehicle,
      numberOfDependents: numberOfDependents ?? this.numberOfDependents,
      bankVerified: bankVerified ?? this.bankVerified,
      transactionCount: transactionCount ?? this.transactionCount,
      emiDetected: emiDetected ?? this.emiDetected,
      ifscCode: ifscCode ?? this.ifscCode,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      estimatedMonthlyIncome: estimatedMonthlyIncome ?? this.estimatedMonthlyIncome,
      selfDeclaredMonthlyIncome: selfDeclaredMonthlyIncome ?? this.selfDeclaredMonthlyIncome,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyEmiObligation: monthlyEmiObligation ?? this.monthlyEmiObligation,
      debtToIncomeRatio: debtToIncomeRatio ?? this.debtToIncomeRatio,
      emiCandidateCount: emiCandidateCount ?? this.emiCandidateCount,
      secondaryIncomeAmount: secondaryIncomeAmount ?? this.secondaryIncomeAmount,
      yearsInCurrentProfession: yearsInCurrentProfession ?? this.yearsInCurrentProfession,
      vehicleOwnerMismatch: vehicleOwnerMismatch ?? this.vehicleOwnerMismatch,
      statementFrom: statementFrom ?? this.statementFrom,
      statementTo: statementTo ?? this.statementTo,
      electricityVerified: electricityVerified ?? this.electricityVerified,
      lpgVerified: lpgVerified ?? this.lpgVerified,
      mobileUtilityVerified: mobileUtilityVerified ?? this.mobileUtilityVerified,
      rentVerified: rentVerified ?? this.rentVerified,
      wifiVerified: wifiVerified ?? this.wifiVerified,
      ottVerified: ottVerified ?? this.ottVerified,
      workProofProvided: workProofProvided ?? this.workProofProvided,
      workProofVerified: workProofVerified ?? this.workProofVerified,
      selectedSvanidhi: selectedSvanidhi ?? this.selectedSvanidhi,
      selectedEShram: selectedEShram ?? this.selectedEShram,
      selectedPmSym: selectedPmSym ?? this.selectedPmSym,
      selectedPmjjby: selectedPmjjby ?? this.selectedPmjjby,
      selectedUdyam: selectedUdyam ?? this.selectedUdyam,
      selectedPpf: selectedPpf ?? this.selectedPpf,
      svanidhiVerified: svanidhiVerified ?? this.svanidhiVerified,
      eShramVerified: eShramVerified ?? this.eShramVerified,
      pmSymVerified: pmSymVerified ?? this.pmSymVerified,
      pmjjbyVerified: pmjjbyVerified ?? this.pmjjbyVerified,
      udyamVerified: udyamVerified ?? this.udyamVerified,
      ppfVerified: ppfVerified ?? this.ppfVerified,
      selectedHealthInsurance: selectedHealthInsurance ?? this.selectedHealthInsurance,
      selectedLifeInsurance: selectedLifeInsurance ?? this.selectedLifeInsurance,
      selectedVehicleInsurance: selectedVehicleInsurance ?? this.selectedVehicleInsurance,
      healthInsuranceVerified: healthInsuranceVerified ?? this.healthInsuranceVerified,
      lifeInsuranceVerified: lifeInsuranceVerified ?? this.lifeInsuranceVerified,
      vehicleInsuranceVerified: vehicleInsuranceVerified ?? this.vehicleInsuranceVerified,
      selectedItr: selectedItr ?? this.selectedItr,
      selectedGst: selectedGst ?? this.selectedGst,
      itrVerified: itrVerified ?? this.itrVerified,
      gstVerified: gstVerified ?? this.gstVerified,
      itrAnnualIncome: itrAnnualIncome ?? this.itrAnnualIncome,
      gstAnnualIncome: gstAnnualIncome ?? this.gstAnnualIncome,
      loanVerificationAttempted: loanVerificationAttempted ?? this.loanVerificationAttempted,
      loanVerificationPassed: loanVerificationPassed ?? this.loanVerificationPassed,
      emiRiskBand: emiRiskBand ?? this.emiRiskBand,
    );
  }

  // ── JSON ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'dateOfBirthText': dateOfBirthText,
      'currentAddress': currentAddress,
      'permanentAddress': permanentAddress,
      'stateOfResidence': stateOfResidence,
      'age': age,
      'workType': workType?.name,
      'minimumGatePassed': minimumGatePassed,
      'currentStep': currentStep.name,
      'verificationState': {
        for (final entry in verificationState.entries) entry.key.name: entry.value.name,
      },
      'featureVector': featureVector,
      'aadhaarVerified': aadhaarVerified,
      'panVerified': panVerified,
      'aadhaarNumber': aadhaarNumber,
      'panNumber': panNumber,
      'faceVerified': faceVerified,
      'faceMatchScore': faceMatchScore,
      'hasVehicle': hasVehicle,
      'numberOfDependents': numberOfDependents,
      'bankVerified': bankVerified,
      'transactionCount': transactionCount,
      'emiDetected': emiDetected,
      'ifscCode': ifscCode,
      'accountNumberMasked': accountNumberMasked,
      'estimatedMonthlyIncome': estimatedMonthlyIncome,
      'selfDeclaredMonthlyIncome': selfDeclaredMonthlyIncome,
      'monthlyIncome': monthlyIncome,
      'monthlyEmiObligation': monthlyEmiObligation,
      'debtToIncomeRatio': debtToIncomeRatio,
      'emiCandidateCount': emiCandidateCount,
      'secondaryIncomeAmount': secondaryIncomeAmount,
      'yearsInCurrentProfession': yearsInCurrentProfession,
      'vehicleOwnerMismatch': vehicleOwnerMismatch,
      'statementFrom': statementFrom?.toIso8601String(),
      'statementTo': statementTo?.toIso8601String(),
      'electricityVerified': electricityVerified,
      'lpgVerified': lpgVerified,
      'mobileUtilityVerified': mobileUtilityVerified,
      'rentVerified': rentVerified,
      'wifiVerified': wifiVerified,
      'ottVerified': ottVerified,
      'workProofProvided': workProofProvided,
      'workProofVerified': workProofVerified,
      'selectedSvanidhi': selectedSvanidhi,
      'selectedEShram': selectedEShram,
      'selectedPmSym': selectedPmSym,
      'selectedPmjjby': selectedPmjjby,
      'selectedUdyam': selectedUdyam,
      'selectedPpf': selectedPpf,
      'svanidhiVerified': svanidhiVerified,
      'eShramVerified': eShramVerified,
      'pmSymVerified': pmSymVerified,
      'pmjjbyVerified': pmjjbyVerified,
      'udyamVerified': udyamVerified,
      'ppfVerified': ppfVerified,
      'selectedHealthInsurance': selectedHealthInsurance,
      'selectedLifeInsurance': selectedLifeInsurance,
      'selectedVehicleInsurance': selectedVehicleInsurance,
      'healthInsuranceVerified': healthInsuranceVerified,
      'lifeInsuranceVerified': lifeInsuranceVerified,
      'vehicleInsuranceVerified': vehicleInsuranceVerified,
      'selectedItr': selectedItr,
      'selectedGst': selectedGst,
      'itrVerified': itrVerified,
      'gstVerified': gstVerified,
      'itrAnnualIncome': itrAnnualIncome,
      'gstAnnualIncome': gstAnnualIncome,
      'loanVerificationAttempted': loanVerificationAttempted,
      'loanVerificationPassed': loanVerificationPassed,
      'emiRiskBand': emiRiskBand,
    };
  }

  factory VerifiedProfile.fromJson(Map<String, dynamic> json) {
    final verificationRaw = (json['verificationState'] as Map<String, dynamic>? ?? {});
    return VerifiedProfile(
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      dateOfBirthText: json['dateOfBirthText'] as String? ?? '',
      currentAddress: json['currentAddress'] as String? ?? '',
      permanentAddress: json['permanentAddress'] as String? ?? '',
      stateOfResidence: json['stateOfResidence'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      workType: WorkType.values.firstWhere(
        (v) => v.name == json['workType'],
        orElse: () => WorkType.platformWorker,
      ),
      minimumGatePassed: json['minimumGatePassed'] as bool? ?? false,
      currentStep: StepId.values.firstWhere(
        (v) => v.name == json['currentStep'],
        orElse: () => StepId.step1Profile,
      ),
      verificationState: {
        for (final step in StepId.values)
          step: StepStatus.values.firstWhere(
            (s) => s.name == verificationRaw[step.name],
            orElse: () => StepStatus.notStarted,
          ),
      },
      featureVector: (json['featureVector'] as List<dynamic>? ?? List<dynamic>.filled(95, 0.0))
          .map((v) => (v as num).toDouble())
          .toList(),
      aadhaarVerified: json['aadhaarVerified'] as bool? ?? false,
      panVerified: json['panVerified'] as bool? ?? false,
      aadhaarNumber: json['aadhaarNumber'] as String? ?? '',
      panNumber: json['panNumber'] as String? ?? '',
      faceVerified: json['faceVerified'] as bool? ?? false,
      faceMatchScore: (json['faceMatchScore'] as num?)?.toDouble() ?? 0.0,
      hasVehicle: json['hasVehicle'] as bool? ?? false,
      numberOfDependents: (json['numberOfDependents'] as num?)?.toInt() ?? 0,
      bankVerified: json['bankVerified'] as bool? ?? false,
      transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
      emiDetected: json['emiDetected'] as bool? ?? false,
      ifscCode: json['ifscCode'] as String? ?? '',
      accountNumberMasked: json['accountNumberMasked'] as String? ?? '',
      estimatedMonthlyIncome: (json['estimatedMonthlyIncome'] as num?)?.toDouble() ?? 0.0,
      selfDeclaredMonthlyIncome: (json['selfDeclaredMonthlyIncome'] as num?)?.toDouble() ?? 0.0,
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0.0,
      monthlyEmiObligation: (json['monthlyEmiObligation'] as num?)?.toDouble() ?? 0.0,
      debtToIncomeRatio: (json['debtToIncomeRatio'] as num?)?.toDouble() ?? 0.0,
      emiCandidateCount: (json['emiCandidateCount'] as num?)?.toInt() ?? 0,
      secondaryIncomeAmount: (json['secondaryIncomeAmount'] as num?)?.toDouble() ?? 0.0,
      yearsInCurrentProfession: (json['yearsInCurrentProfession'] as num?)?.toInt() ?? 0,
      vehicleOwnerMismatch: json['vehicleOwnerMismatch'] as bool? ?? false,
      statementFrom: json['statementFrom'] != null
          ? DateTime.tryParse(json['statementFrom'] as String)
          : null,
      statementTo: json['statementTo'] != null
          ? DateTime.tryParse(json['statementTo'] as String)
          : null,
      electricityVerified: json['electricityVerified'] as bool? ?? false,
      lpgVerified: json['lpgVerified'] as bool? ?? false,
      mobileUtilityVerified: json['mobileUtilityVerified'] as bool? ?? false,
      rentVerified: json['rentVerified'] as bool? ?? false,
      wifiVerified: json['wifiVerified'] as bool? ?? false,
      ottVerified: json['ottVerified'] as bool? ?? false,
      workProofProvided: json['workProofProvided'] as bool? ?? false,
      workProofVerified: json['workProofVerified'] as bool? ?? false,
      selectedSvanidhi: json['selectedSvanidhi'] as bool? ?? false,
      selectedEShram: json['selectedEShram'] as bool? ?? false,
      selectedPmSym: json['selectedPmSym'] as bool? ?? false,
      selectedPmjjby: json['selectedPmjjby'] as bool? ?? false,
      selectedUdyam: json['selectedUdyam'] as bool? ?? false,
      selectedPpf: json['selectedPpf'] as bool? ?? false,
      svanidhiVerified: json['svanidhiVerified'] as bool? ?? false,
      eShramVerified: json['eShramVerified'] as bool? ?? false,
      pmSymVerified: json['pmSymVerified'] as bool? ?? false,
      pmjjbyVerified: json['pmjjbyVerified'] as bool? ?? false,
      udyamVerified: json['udyamVerified'] as bool? ?? false,
      ppfVerified: json['ppfVerified'] as bool? ?? false,
      selectedHealthInsurance: json['selectedHealthInsurance'] as bool? ?? false,
      selectedLifeInsurance: json['selectedLifeInsurance'] as bool? ?? false,
      selectedVehicleInsurance: json['selectedVehicleInsurance'] as bool? ?? false,
      healthInsuranceVerified: json['healthInsuranceVerified'] as bool? ?? false,
      lifeInsuranceVerified: json['lifeInsuranceVerified'] as bool? ?? false,
      vehicleInsuranceVerified: json['vehicleInsuranceVerified'] as bool? ?? false,
      selectedItr: json['selectedItr'] as bool? ?? false,
      selectedGst: json['selectedGst'] as bool? ?? false,
      itrVerified: json['itrVerified'] as bool? ?? false,
      gstVerified: json['gstVerified'] as bool? ?? false,
      itrAnnualIncome: (json['itrAnnualIncome'] as num?)?.toDouble() ?? 0.0,
      gstAnnualIncome: (json['gstAnnualIncome'] as num?)?.toDouble() ?? 0.0,
      loanVerificationAttempted: json['loanVerificationAttempted'] as bool? ?? false,
      loanVerificationPassed: json['loanVerificationPassed'] as bool? ?? false,
      emiRiskBand: json['emiRiskBand'] as String? ?? 'LOW',
    );
  }
}

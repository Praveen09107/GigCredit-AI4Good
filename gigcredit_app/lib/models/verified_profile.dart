import 'enums/step_status.dart';
import 'enums/work_type.dart';

class VerifiedProfile {
  const VerifiedProfile({
    required this.fullName,
    required this.phoneNumber,
    required this.monthlyIncome,
    required this.workType,
    required this.minimumGatePassed,
    required this.currentStep,
    required this.verificationState,
    required this.featureVector,
  });

  factory VerifiedProfile.initial() {
    return VerifiedProfile(
      fullName: '',
      phoneNumber: '',
      monthlyIncome: 15000,
      workType: WorkType.platformWorker,
      minimumGatePassed: false,
      currentStep: StepId.step1Profile,
      verificationState: {
        for (final step in StepId.values) step: StepStatus.notStarted,
      },
      featureVector: List<double>.filled(95, 0.5),
    );
  }

  final String fullName;
  final String phoneNumber;
  final double monthlyIncome;
  final WorkType workType;
  final bool minimumGatePassed;
  final StepId currentStep;
  final Map<StepId, StepStatus> verificationState;
  final List<double> featureVector;

  VerifiedProfile copyWith({
    String? fullName,
    String? phoneNumber,
    double? monthlyIncome,
    WorkType? workType,
    bool? minimumGatePassed,
    StepId? currentStep,
    Map<StepId, StepStatus>? verificationState,
    List<double>? featureVector,
  }) {
    return VerifiedProfile(
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      workType: workType ?? this.workType,
      minimumGatePassed: minimumGatePassed ?? this.minimumGatePassed,
      currentStep: currentStep ?? this.currentStep,
      verificationState: verificationState ?? this.verificationState,
      featureVector: featureVector ?? this.featureVector,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'monthlyIncome': monthlyIncome,
      'workType': workType.name,
      'minimumGatePassed': minimumGatePassed,
      'currentStep': currentStep.name,
      'verificationState': {
        for (final entry in verificationState.entries) entry.key.name: entry.value.name,
      },
      'featureVector': featureVector,
    };
  }

  factory VerifiedProfile.fromJson(Map<String, dynamic> json) {
    final verificationRaw = (json['verificationState'] as Map<String, dynamic>? ?? {});
    return VerifiedProfile(
      fullName: json['fullName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 15000,
      workType: WorkType.values.firstWhere(
        (value) => value.name == json['workType'],
        orElse: () => WorkType.platformWorker,
      ),
      minimumGatePassed: json['minimumGatePassed'] as bool? ?? false,
      currentStep: StepId.values.firstWhere(
        (value) => value.name == json['currentStep'],
        orElse: () => StepId.step1Profile,
      ),
      verificationState: {
        for (final step in StepId.values)
          step: StepStatus.values.firstWhere(
            (status) => status.name == verificationRaw[step.name],
            orElse: () => StepStatus.notStarted,
          ),
      },
      featureVector: (json['featureVector'] as List<dynamic>? ?? List<dynamic>.filled(95, 0.5))
          .map((value) => (value as num).toDouble())
          .toList(),
    );
  }
}


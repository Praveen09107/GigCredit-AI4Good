import '../models/enums/work_type.dart';

class MetaLearnerCoefficients {
  const MetaLearnerCoefficients({
    required this.coefficients,
    required this.intercept,
    required this.source,
  });

  final List<double> coefficients;
  final double intercept;
  final String source;
}

class DevAHandoffAdapter {
  // Replace this with official handoff payload once Dev A provides
  // assets/constants/meta_coefficients.json with 20 LR coefficients + intercept.
  static const MetaLearnerCoefficients fallback = MetaLearnerCoefficients(
    coefficients: <double>[
      1.2, 0.8, 1.5, 0.4, -0.6, 2.1, 0.3, 1.1, 0.5, 0.4,
      0.6, 0.9, 0.2, 0.1, 0.3, 0.8, -0.2, 0.4, 0.7, 0.5,
    ],
    intercept: -0.25,
    source: 'synthetic-prod',
  );

  static MetaLearnerCoefficients fromJsonMap(Map<String, dynamic> map, {String source = 'dev_a_handoff'}) {
    final rawCoefficients = map['coefficients'];
    final rawIntercept = map['intercept'];

    if (rawCoefficients is! List || rawIntercept == null) {
      return fallback;
    }

    final parsed = rawCoefficients
        .map((e) => e is num ? e.toDouble() : double.tryParse('$e') ?? 0.0)
        .toList(growable: false);

    final intercept = rawIntercept is num
        ? rawIntercept.toDouble()
        : double.tryParse('$rawIntercept') ?? 0.0;

    if (parsed.length != 20) {
      return fallback;
    }

    return MetaLearnerCoefficients(
      coefficients: parsed,
      intercept: intercept,
      source: source,
    );
  }

  // Builds canonical 20 meta inputs from 8 pillar-like proxies + one-hot + interactions.
  static List<double> buildMetaInput20({
    required List<double> pillars8,
    required WorkType? workType,
  }) {
    if (pillars8.length != 8) {
      throw ArgumentError('pillars8 must have 8 values.');
    }

    final isPlatform = workType == WorkType.platformWorker ? 1.0 : 0.0;
    final isVendor = workType == WorkType.vendor ? 1.0 : 0.0;
    final isSkilled = workType == WorkType.tradesperson ? 1.0 : 0.0;
    final isFreelancer = workType == WorkType.freelancer ? 1.0 : 0.0;

    final selected = [isPlatform, isVendor, isSkilled, isFreelancer].reduce((a, b) => a + b) > 0
        ? [isPlatform, isVendor, isSkilled, isFreelancer].reduce((a, b) => a + b)
        : 0.0;

    final interactions = pillars8.map((p) => p * selected).toList(growable: false);

    return <double>[
      ...pillars8,
      isPlatform,
      isVendor,
      isSkilled,
      isFreelancer,
      ...interactions,
    ];
  }
}

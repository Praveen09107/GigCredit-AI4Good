import 'dart:math' as math;

import 'feature_sanitizer.dart';
import 'generated/p1_scorer.dart' as p1;
import 'generated/p2_scorer.dart' as p2;
import 'generated/p3_scorer.dart' as p3;
import 'generated/p4_scorer.dart' as p4;
import 'generated/p6_scorer.dart' as p6;
import 'meta_learner.dart';

class ScoringOutcome {
  const ScoringOutcome({
    required this.eligible,
    required this.finalScore,
    required this.probability,
    required this.pillarScores,
    required this.riskBand,
  });

  final bool eligible;
  final int finalScore;
  final double probability;
  final Map<String, double> pillarScores;
  final String riskBand;
}

class ScoringEngine {
  ScoringEngine({MetaLearnerService? metaLearnerService})
      : _metaLearnerService = metaLearnerService ?? MetaLearnerService();

  final MetaLearnerService _metaLearnerService;

  Future<ScoringOutcome> score({
    required List<double> rawFeatures,
    required bool minimumGatePassed,
    required int workTypeIndex,
  }) async {
    if (!minimumGatePassed) {
      return const ScoringOutcome(
        eligible: false,
        finalScore: 300,
        probability: 0.0,
        pillarScores: {
          'p1': 0.0,
          'p2': 0.0,
          'p3': 0.0,
          'p4': 0.0,
          'p5': 0.0,
          'p6': 0.0,
          'p7': 0.0,
          'p8': 0.0,
        },
        riskBand: 'ineligible',
      );
    }

    final features = sanitizeFeatures(rawFeatures, expectedLength: 95);

    final p1Input = features.sublist(0, 13);
    final p2Input = features.sublist(13, 28);
    final p3Input = features.sublist(28, 37);
    final p4Input = features.sublist(37, 49);
    final p5Input = features.sublist(49, 67);
    final p6Input = features.sublist(67, 78);
    final p7Input = features.sublist(78, 88);
    final p8Input = features.sublist(88, 95);

    var p1Score = p1.scoreP1(p1Input);
    var p2Score = p2.scoreP2(p2Input);
    var p3Score = p3.scoreP3(p3Input);
    var p4Score = p4.scoreP4(p4Input);
    final p5Score = _scorecardMean(p5Input);
    final p6Score = p6.scoreP6(p6Input);
    final p7Score = _scorecardMean(p7Input);
    final p8Score = _scorecardMean(p8Input);

    final debtToIncomeRatio = features[36];
    if (debtToIncomeRatio > 0.80) {
      p3Score = math.min(p3Score, 0.30);
    }

    p1Score = _confidenceAdjust(p1Score);
    p2Score = _confidenceAdjust(p2Score);
    p3Score = _confidenceAdjust(p3Score);
    p4Score = _confidenceAdjust(p4Score);

    final pillars = <double>[p1Score, p2Score, p3Score, p4Score, p5Score, p6Score, p7Score, p8Score];
    final oneHot = _workTypeOneHot(workTypeIndex);
    final metaInput = <double>[...pillars, ...oneHot];

    for (final pillar in pillars) {
      for (final workFlag in oneHot) {
        metaInput.add(pillar * workFlag);
      }
    }

    final probability = await _metaLearnerService.predictProbability(metaInput);
    final boundedProbability = probability.clamp(0.0, 1.0);
    final finalScore = (300 + boundedProbability * 600).round().clamp(300, 900);

    return ScoringOutcome(
      eligible: true,
      finalScore: finalScore,
      probability: boundedProbability,
      pillarScores: {
        'p1': p1Score,
        'p2': p2Score,
        'p3': p3Score,
        'p4': p4Score,
        'p5': p5Score,
        'p6': p6Score,
        'p7': p7Score,
        'p8': p8Score,
      },
      riskBand: _riskBand(finalScore),
    );
  }

  double _scorecardMean(List<double> values) {
    if (values.isEmpty) {
      return 0.5;
    }
    final sum = values.fold<double>(0.0, (previousValue, element) => previousValue + element);
    return (sum / values.length).clamp(0.0, 1.0);
  }

  double _confidenceAdjust(double raw, {double confidence = 1.0}) {
    final adjusted = raw * confidence + 0.5 * (1 - confidence);
    return adjusted.clamp(0.0, 1.0);
  }

  List<double> _workTypeOneHot(int workTypeIndex) {
    final index = workTypeIndex.clamp(0, 3);
    return List<double>.generate(4, (position) => position == index ? 1.0 : 0.0, growable: false);
  }

  String _riskBand(int score) {
    if (score <= 450) {
      return 'high';
    }
    if (score <= 650) {
      return 'medium';
    }
    return 'low';
  }
}

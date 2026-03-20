import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/scoring/meta_learner.dart';
import 'package:gigcredit_app/scoring/scoring_engine.dart';

class _CapturingMetaLearnerService extends MetaLearnerService {
  List<double>? lastInput;

  @override
  Future<double> predictProbability(List<double> input44) async {
    lastInput = List<double>.from(input44);
    return 0.6;
  }
}

void main() {
  group('Scoring contract guardrails', () {
    test('builds frozen 44-length meta input for scorer runtime', () async {
      final metaService = _CapturingMetaLearnerService();
      final engine = ScoringEngine(metaLearnerService: metaService);

      final outcome = await engine.score(
        rawFeatures: List<double>.filled(95, 0.7),
        minimumGatePassed: true,
        workTypeIndex: 2,
      );

      expect(metaService.lastInput, isNotNull);
      expect(metaService.lastInput, hasLength(44));
      expect(outcome.eligible, isTrue);
    });

    test('returns p1 through p8 pillar outputs for eligible scoring', () async {
      final metaService = _CapturingMetaLearnerService();
      final engine = ScoringEngine(metaLearnerService: metaService);

      final outcome = await engine.score(
        rawFeatures: List<double>.filled(95, 0.5),
        minimumGatePassed: true,
        workTypeIndex: 1,
      );

      expect(outcome.pillarScores.keys, containsAll(<String>['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8']));
    });
  });
}

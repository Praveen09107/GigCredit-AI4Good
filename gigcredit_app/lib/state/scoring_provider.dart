import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../scoring/scoring_engine.dart';

class ScoringRequest {
  const ScoringRequest({
    required this.features,
    required this.minimumGatePassed,
    required this.workTypeIndex,
  });

  final List<double> features;
  final bool minimumGatePassed;
  final int workTypeIndex;
}

final scoringEngineProvider = Provider<ScoringEngine>((ref) {
  return ScoringEngine();
});

final scoringOutcomeProvider = FutureProvider.family<ScoringOutcome, ScoringRequest>((ref, request) async {
  final engine = ref.watch(scoringEngineProvider);
  return engine.score(
    rawFeatures: request.features,
    minimumGatePassed: request.minimumGatePassed,
    workTypeIndex: request.workTypeIndex,
  );
});

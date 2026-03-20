import '../models/verified_profile.dart';
import 'feature_engineering.dart';
import 'feature_sanitizer.dart';

class ScoringPipeline {
  const ScoringPipeline();

  List<double> buildSanitizedVector95(VerifiedProfile profile) {
    final raw = FeatureEngineering.buildFeatureVector(profile);
    return sanitizeFeatures(raw);
  }
}

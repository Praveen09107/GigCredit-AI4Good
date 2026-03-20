import 'dart:math';

class ScoreFormula {
  static double sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  // Frozen score transform: round(300 + sigmoid(logit) * 600)
  static int scoreFromLogit(double logit) {
    final prob = sigmoid(logit);
    return (300 + prob * 600).round().clamp(300, 900);
  }
}

double scoreP7(List<double> input) {
  if (input.isEmpty) {
    return 0.5;
  }
  final sum = input.fold<double>(0.0, (acc, value) => acc + value);
  final score = sum / input.length;
  if (score.isNaN || score.isInfinite) {
    return 0.5;
  }
  return score.clamp(0.0, 1.0);
}

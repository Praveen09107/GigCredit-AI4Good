import 'dart:math' as math;

List<double> sanitizeFeatures(List<double> rawFeatures, {int expectedLength = 95}) {
  final output = List<double>.filled(expectedLength, 0.5);

  final copyLength = math.min(rawFeatures.length, expectedLength);
  for (var index = 0; index < copyLength; index++) {
    final value = rawFeatures[index];
    if (value.isNaN || value.isInfinite) {
      output[index] = 0.5;
      continue;
    }
    if (value < 0.0) {
      output[index] = 0.0;
    } else if (value > 1.0) {
      output[index] = 1.0;
    } else {
      output[index] = value;
    }
  }

  return output;
}

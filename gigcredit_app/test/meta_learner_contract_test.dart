import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Meta learner artifact contract', () {
    test('shipped meta coefficients keep frozen 44-input schema', () {
      final artifact = File('assets/constants/meta_coefficients.json');
      expect(artifact.existsSync(), isTrue);

      final raw = jsonDecode(artifact.readAsStringSync()) as Map<String, dynamic>;
      final inputLength = raw['input_length'] as int;
      final coefficients = (raw['coefficients'] as List<dynamic>).cast<num>();
      final scalerMean = (raw['scaler_mean'] as List<dynamic>).cast<num>();
      final scalerStd = (raw['scaler_std'] as List<dynamic>).cast<num>();

      expect(inputLength, 44);
      expect(coefficients, hasLength(44));
      expect(scalerMean, hasLength(44));
      expect(scalerStd, hasLength(44));

      for (final value in scalerStd) {
        expect(value.isFinite, isTrue);
      }
    });
  });
}

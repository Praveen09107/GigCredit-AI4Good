import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

class MetaLearnerModel {
  const MetaLearnerModel({
    required this.inputLength,
    required this.coefficients,
    required this.intercept,
    required this.scalerMean,
    required this.scalerStd,
  });

  final int inputLength;
  final List<double> coefficients;
  final double intercept;
  final List<double> scalerMean;
  final List<double> scalerStd;

  static MetaLearnerModel fromJson(Map<String, dynamic> json) {
    return MetaLearnerModel(
      inputLength: json['input_length'] as int,
      coefficients: (json['coefficients'] as List<dynamic>).cast<num>().map((value) => value.toDouble()).toList(growable: false),
      intercept: (json['intercept'] as num).toDouble(),
      scalerMean: (json['scaler_mean'] as List<dynamic>).cast<num>().map((value) => value.toDouble()).toList(growable: false),
      scalerStd: (json['scaler_std'] as List<dynamic>).cast<num>().map((value) => value.toDouble()).toList(growable: false),
    );
  }
}

class MetaLearnerService {
  MetaLearnerModel? _cachedModel;

  Future<MetaLearnerModel> load() async {
    final cached = _cachedModel;
    if (cached != null) {
      return cached;
    }

    final jsonText = await rootBundle.loadString('assets/constants/meta_coefficients.json');
    final parsed = json.decode(jsonText) as Map<String, dynamic>;
    final model = MetaLearnerModel.fromJson(parsed);
    _cachedModel = model;
    return model;
  }

  Future<double> predictProbability(List<double> input44) async {
    final model = await load();
    if (input44.length != model.inputLength) {
      throw ArgumentError('Expected ${model.inputLength} meta features, got ${input44.length}.');
    }

    final standardized = List<double>.generate(model.inputLength, (index) {
      final std = model.scalerStd[index];
      if (std == 0.0 || std.isNaN || std.isInfinite) {
        return 0.0;
      }
      return (input44[index] - model.scalerMean[index]) / std;
    }, growable: false);

    var linear = model.intercept;
    for (var index = 0; index < model.inputLength; index++) {
      linear += standardized[index] * model.coefficients[index];
    }

    return _sigmoid(linear);
  }

  double _sigmoid(double value) {
    if (value >= 0) {
      final z = math.exp(-value);
      return 1.0 / (1.0 + z);
    }
    final z = math.exp(value);
    return z / (1.0 + z);
  }
}

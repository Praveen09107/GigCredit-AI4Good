import 'dart:convert';
import 'dart:io';

import 'package:gigcredit_app/scoring/score_formula.dart';

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  final fixture = File('test/golden/score_cases_expected.json');
  _expect(fixture.existsSync(), 'Golden fixture missing: ${fixture.path}');

  final json = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
  final cases = (json['cases'] as List).cast<Map<String, dynamic>>();

  var previousLogit = -1e99;
  var previousScore = -1;

  for (final c in cases) {
    final logit = (c['logit'] as num).toDouble();
    final expected = (c['expectedScore'] as num).toInt();
    final actual = ScoreFormula.scoreFromLogit(logit);

    _expect(actual == expected, 'Score mismatch for logit $logit. Expected $expected, got $actual.');
    _expect(actual >= 300 && actual <= 900, 'Score out of frozen bounds for logit $logit: $actual');

    if (logit > previousLogit) {
      _expect(actual >= previousScore, 'Score monotonicity violated at logit $logit.');
      previousLogit = logit;
      previousScore = actual;
    }
  }
}

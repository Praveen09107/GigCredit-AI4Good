import 'package:gigcredit_app/scoring/score_formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScoreFormula bounds and maps logic to score properly', () {
    final scoreMid = ScoreFormula.scoreFromLogit(0);
    expect(scoreMid, 600, reason: 'Logit 0 should map to score 600.');

    final scoreHigh = ScoreFormula.scoreFromLogit(20);
    expect(scoreHigh <= 900 && scoreHigh >= 300, isTrue, reason: 'Score must stay in 300..900 bounds (high logit).');

    final scoreLow = ScoreFormula.scoreFromLogit(-20);
    expect(scoreLow <= 900 && scoreLow >= 300, isTrue, reason: 'Score must stay in 300..900 bounds (low logit).');

    expect(scoreHigh >= scoreMid, isTrue, reason: 'Higher logit should not produce lower score.');
    expect(scoreMid >= scoreLow, isTrue, reason: 'Lower logit should not produce higher score.');
  });
}

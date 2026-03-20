import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/scoring/scorecard_p5.dart' as p5;
import 'package:gigcredit_app/scoring/scorecard_p7.dart' as p7;
import 'package:gigcredit_app/scoring/scorecard_p8.dart' as p8;

void main() {
  test('scorecards return bounded means', () {
    expect(p5.scoreP5([0.2, 0.4, 0.8]), closeTo(0.4666, 0.001));
    expect(p7.scoreP7([0.0, 1.0]), closeTo(0.5, 0.001));
    expect(p8.scoreP8([0.9, 0.9, 0.9]), closeTo(0.9, 0.001));
  });

  test('scorecards fallback safely for empty input', () {
    expect(p5.scoreP5([]), 0.5);
    expect(p7.scoreP7([]), 0.5);
    expect(p8.scoreP8([]), 0.5);
  });
}

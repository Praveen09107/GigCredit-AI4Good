import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/scoring/feature_engineering.dart';
import 'package:gigcredit_app/scoring/feature_sanitizer.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FeatureEngineering parses 95 dimensional vector correctly', () {
    final profile = VerifiedProfile.initial().copyWith(
      age: 31,
      hasVehicle: true,
      aadhaarVerified: true,
      panVerified: true,
      faceVerified: true,
      faceMatchScore: 0.92,
      bankVerified: true,
      transactionCount: 86,
      monthlyEmiObligation: 4200,
      estimatedMonthlyIncome: 28000,
      debtToIncomeRatio: 0.15,
    );

    final raw = FeatureEngineering.buildFeatureVector(profile);
    expect(raw.length, 95, reason: 'Feature vector must have exactly 95 values.');

    // Test that the sanitizer correctly clamps out-of-range and non-finite values
    final testInput = [
      double.nan,      // [0] → should become 0.5 (default for NaN)
      double.infinity, // [1] → should become 0.5 (default for Inf)
      double.negativeInfinity, // [2] → should become 0.5
      -10.0,           // [3] → below 0.0, should clamp to 0.0
      0.8,             // [4] → valid in-range value, should remain unchanged
      10.0,            // [5] → above 1.0, should clamp to 1.0
    ];

    final sanitized = sanitizeFeatures(testInput, expectedLength: testInput.length);

    expect(sanitized[0], 0.5, reason: 'NaN should sanitize to default 0.5.');
    expect(sanitized[1], 0.5, reason: 'Infinity should sanitize to default 0.5.');
    expect(sanitized[2], 0.5, reason: '-Infinity should sanitize to default 0.5.');
    expect(sanitized[3], 0.0, reason: 'Value below min (0.0) should clamp to 0.0.');
    expect(sanitized[4], 0.8, reason: 'Valid in-range value should remain unchanged.');
    expect(sanitized[5], 1.0, reason: 'Value above max (1.0) should clamp to 1.0.');
  });
}

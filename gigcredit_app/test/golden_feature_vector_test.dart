import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/models/enums/step_id.dart';
import 'package:gigcredit_app/models/enums/step_status.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/scoring/feature_engineering.dart';

void main() {
  test('feature vector matches golden anchors', () {
    final fixture = File('test/golden/feature_vector_expected.json');
    expect(fixture.existsSync(), isTrue, reason: 'Golden fixture missing: ${fixture.path}');

    final json = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
    final expectedLength = (json['expectedLength'] as num).toInt();
    final expectedAnchors = (json['expectedAnchors'] as Map).cast<String, dynamic>();

    final profile = VerifiedProfile.initial().copyWith(
      fullName: 'Test User',
      phoneNumber: '9876543210',
      age: 30,
      workType: WorkType.platformWorker,
      minimumGatePassed: true,
      currentStep: StepId.step9EmiLoan,
      verificationState: {
        for (final step in StepId.values) step: StepStatus.verified,
      },
      hasVehicle: true,
      numberOfDependents: 2,
      bankVerified: true,
      transactionCount: 22,
      statementFrom: DateTime(2023, 1, 1),
      statementTo: DateTime(2023, 6, 30),
      faceVerified: true,
      faceMatchScore: 0.92,
      electricityVerified: true,
      mobileUtilityVerified: true,
      itrAnnualIncome: 480000,
      monthlyEmiObligation: 5000,
      estimatedMonthlyIncome: 40000,
      selfDeclaredMonthlyIncome: 35000,
      debtToIncomeRatio: 0.125,
      ifscCode: 'SBIN0000001',
    );

    final vector = FeatureEngineering.buildFeatureVector(profile);
    expect(vector.length, expectedLength);

    for (final entry in expectedAnchors.entries) {
      final index = int.parse(entry.key);
      final expected = (entry.value as num).toDouble();
      final actual = vector[index];
      expect(
        (actual - expected).abs() <= 1e-9,
        isTrue,
        reason: 'Feature mismatch at index $index. Expected $expected, got $actual.',
      );
    }
  });
}

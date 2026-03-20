import 'dart:convert';
import 'dart:io';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/scoring/feature_engineering.dart';

void main() {
  final p = VerifiedProfile.initial().copyWith(
    age: 30,
    workType: WorkType.platformWorker,
    selfDeclaredMonthlyIncome: 35000.0,
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
    debtToIncomeRatio: 0.125,
    ifscCode: 'SBIN0000001',
  );

  final features = FeatureEngineering.buildFeatureVector(p);
  final expectedAnchors = <String, double>{};
  for (int i = 0; i < features.length; i++) {
    if (features[i] != 0.0) {
      expectedAnchors[i.toString()] = features[i];
    }
  }

  final out = {
    "description": "Golden anchors for feature vector generated from fixed profile fixture",
    "expectedLength": 95,
    "expectedAnchors": expectedAnchors,
  };

  File('test/golden/feature_vector_expected.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
}

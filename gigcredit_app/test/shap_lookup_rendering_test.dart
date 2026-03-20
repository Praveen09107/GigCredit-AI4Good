import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/models/enums/step_id.dart';
import 'package:gigcredit_app/models/enums/step_status.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/scoring/shap_lookup_service.dart';

void main() {
  const allowedDriverKeys = <String>{
    'bank_verified',
    'pan_verified',
    'aadhaar_verified',
    'itr_verified',
    'gst_verified',
    'insurance_verified',
    'work_verified',
    'utility_coverage',
    'scheme_enrollment',
    'high_dti',
    'no_tax_docs',
    'low_transaction_depth',
    'high_emi_burden',
    'no_face_verify',
    'no_work_proof',
  };

  VerifiedProfile buildProfile(List<double> featureVector) {
    return VerifiedProfile(
      fullName: 'Test User',
      phoneNumber: '9876543210',
      dateOfBirthText: '01/01/1995',
      currentAddress: '12 MG Road',
      permanentAddress: '12 MG Road',
      stateOfResidence: 'Tamil Nadu',
      age: 30,
      workType: WorkType.platformWorker,
      minimumGatePassed: false,
      currentStep: StepId.step9EmiLoan,
      verificationState: {
        for (final step in StepId.values) step: StepStatus.notStarted,
      },
      featureVector: featureVector,
    );
  }

  group('ShapLookupService', () {
    test('computes top positive and negative drivers from binned lookup schema', () {
      final service = ShapLookupService(
        lookupOverride: {
          'schema_version': '1.0',
          'pillars': {
            'p2': {
              'f_09': {
                'edges': [0.0, 0.5, 1.0],
                'shap': [-0.2, 0.6],
              },
              'f_17': {
                'edges': [0.0, 0.3, 1.0],
                'shap': [0.1, -0.7],
              },
            },
          },
        },
      );

      final profile = buildProfile(
        List<double>.filled(95, 0.0)
          ..[9] = 0.9
          ..[17] = 0.8,
      );

      final explanation = service.explain(profile, featureVector95: profile.featureVector);

      expect(explanation.positiveDriverKeys, isNotEmpty);
      expect(explanation.negativeDriverKeys, isNotEmpty);
      expect(explanation.positiveDriverKeys, contains('bank_verified'));
      expect(explanation.negativeDriverKeys, contains('high_dti'));
      expect(explanation.driverImpacts['bank_verified']! > 0, isTrue);
      expect(explanation.driverImpacts['high_dti']! < 0, isTrue);
    });

    test('uses shipped lookup schema without surfacing raw feature keys', () {
      final lookupPath = File('assets/constants/shap_lookup.json');
      expect(lookupPath.existsSync(), isTrue);

      final raw = jsonDecode(lookupPath.readAsStringSync()) as Map<String, dynamic>;
      final service = ShapLookupService(lookupOverride: raw);
      final profile = buildProfile(
        List<double>.filled(95, 0.0)
          ..[2] = 0.9
          ..[11] = 0.7
          ..[36] = 0.8
          ..[61] = 0.5,
      );

      final explanation = service.explain(profile, featureVector95: profile.featureVector);

      expect(explanation.driverImpacts, isNotEmpty);
      expect(
        explanation.driverImpacts.keys.any((key) => key.startsWith('f_')),
        isFalse,
      );
      for (final key in explanation.driverImpacts.keys) {
        expect(allowedDriverKeys.contains(key), isTrue);
      }

      for (final key in explanation.positiveDriverKeys) {
        expect(explanation.driverImpacts.containsKey(key), isTrue);
        expect(explanation.driverImpacts[key]! > 0, isTrue);
      }
      for (final key in explanation.negativeDriverKeys) {
        expect(explanation.driverImpacts.containsKey(key), isTrue);
        expect(explanation.driverImpacts[key]! < 0, isTrue);
      }
    });

    test('treats SHAP as explanation-only from feature vector input', () {
      final lookupPath = File('assets/constants/shap_lookup.json');
      expect(lookupPath.existsSync(), isTrue);

      final raw = jsonDecode(lookupPath.readAsStringSync()) as Map<String, dynamic>;
      final service = ShapLookupService(lookupOverride: raw);
      final vector = List<double>.filled(95, 0.0)
        ..[2] = 0.9
        ..[11] = 0.7
        ..[36] = 0.8
        ..[61] = 0.5;

      final profileA = buildProfile(vector)
          .copyWith(
            bankVerified: true,
            panVerified: true,
            aadhaarVerified: true,
          );
      final profileB = buildProfile(vector)
          .copyWith(
            bankVerified: false,
            panVerified: false,
            aadhaarVerified: false,
            gstVerified: false,
            itrVerified: false,
          );

      final explanationA = service.explain(profileA, featureVector95: vector);
      final explanationB = service.explain(profileB, featureVector95: vector);

      expect(explanationA.driverImpacts, explanationB.driverImpacts);
      expect(explanationA.positiveDriverKeys, explanationB.positiveDriverKeys);
      expect(explanationA.negativeDriverKeys, explanationB.negativeDriverKeys);
    });

  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:gigcredit_app/models/enums/report_language.dart';
import 'package:gigcredit_app/models/enums/work_type.dart';
import 'package:gigcredit_app/models/verified_profile.dart';
import 'package:gigcredit_app/models/credit_report.dart';
import 'package:gigcredit_app/scoring/scoring_pipeline.dart';
import 'package:gigcredit_app/scoring/shap_lookup_service.dart';
import 'package:gigcredit_app/services/report_export_service.dart';

void main() {
  // Allow real HTTP requests in flutter test environment to download fonts
  HttpOverrides.global = null;

  test('Generate end-to-end PDF report to desktop', () async {
    // 1. Create a highly optimistic synthesized profile representing Steps 1 to 9 completion
    final mockProfile = VerifiedProfile.initial().copyWith(
      fullName: 'Praveen Developer',
      age: 30,
      workType: WorkType.platformWorker,
      hasVehicle: true,
      numberOfDependents: 2,
      transactionCount: 450,
      monthlyEmiObligation: 3500,
      estimatedMonthlyIncome: 35000,
      selfDeclaredMonthlyIncome: 35000,
      debtToIncomeRatio: 0.1,
      emiRiskBand: 'LOW',
      aadhaarVerified: true,
      panVerified: true,
      faceVerified: true,
      bankVerified: true,
      itrVerified: true,
      gstVerified: true,
      healthInsuranceVerified: true,
      lifeInsuranceVerified: true,
    );

    print('✓ Fake VerifiedProfile created.');

    // 2. Build sanitized feature vector
    final scoringPipeline = const ScoringPipeline();
    final featureVector = scoringPipeline.buildSanitizedVector95(mockProfile);
    // Use a simple heuristic final score (300–900 range) from mean of vector
    final meanVal = featureVector.fold<double>(0, (a, b) => a + b) / featureVector.length;
    final finalScore = (300 + meanVal * 600).round().clamp(300, 900);
    print('✓ ML Score Computed: $finalScore');

    final shapService = ShapLookupService();
    final explanation = shapService.explain(mockProfile);

    // 3. Generate the CreditReport payload
    final report = CreditReport(
      profileName: mockProfile.fullName,
      score: finalScore,
      riskBand: mockProfile.emiRiskBand,
      summary:
          'Your profile has been assessed using verified onboarding data. '
          'An excellent history of transaction depth and compliance has generated '
          'a very positive risk assessment.',
      positives: explanation.positiveDriverKeys
          .map((k) => k.replaceAll('_', ' ').toUpperCase())
          .toList(),
      concerns: ['Mild dependency on gig-based variable income schedules.'],
      generatedAt: DateTime.now(),
      language: ReportLanguage.english,
    );
    print('✓ Internal CreditReport object populated.');

    // 4. Connect to ReportExportService
    final exporter = ReportExportService();
    final bytes = await exporter.buildPdfBytes(report);

    // 5. Output to Desktop
    final path = 'C:/Users/PRAVEEN/Desktop/GigCredit_Demo_Report.pdf';
    final file = File(path);
    file.writeAsBytesSync(bytes);

    print('SUCCESS: Exported PDF payload directly to: $path');
  });
}

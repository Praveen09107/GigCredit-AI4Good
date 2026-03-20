/// Run with: dart tool/generate_demo_report.dart
/// Generates a GigCredit demo PDF report using fully simulated Step-1 to Step-9 data.

import 'dart:io';
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─────────────────────────────────────────────────────────────────────────────
// SIMULATED 9-STEP DATA (Fake Profile for Demonstration)
// ─────────────────────────────────────────────────────────────────────────────
const String applicantName     = 'Praveen R.';
const String workType          = 'Platform Worker (Gig)';
const int    age               = 28;
const String state             = 'Tamil Nadu';
const int    dependents        = 2;

// Step-2: KYC
const bool aadhaarVerified = true;
const bool panVerified     = true;
const bool faceVerified    = true;
const double faceScore     = 0.97;

// Step-3: Bank
const bool bankVerified       = true;
const int  transactionCount   = 420;
const bool emiDetected        = true;

// Step-4: Utilities
const bool electricityVerified = true;
const bool mobileVerified      = true;
const bool wifiVerified        = false;

// Step-5: Work Proof
const bool workProofVerified = true;

// Step-6: Govt Schemes
const bool svanidhiVerified = true;
const bool eShramVerified   = true;

// Step-7: Insurance
const bool healthInsurance = true;
const bool lifeInsurance   = false;
const bool vehicleInsurance = true;

// Step-8: ITR/GST
const bool itrVerified = true;
const bool gstVerified = false;
const double itrAnnualIncome = 320000;

// Step-9: EMI/Loan
const double monthlyEmi        = 3500;
const double monthlyIncome     = 32000;
const double debtToIncomeRatio = 0.109;
const String riskBand          = 'LOW';
const bool loanVerified        = true;

// ─────────────────────────────────────────────────────────────────────────────
// SCORING SIMULATION
// ─────────────────────────────────────────────────────────────────────────────
int computeScore() {
  double logit = -0.25;

  // Pillar weights (synthetic)
  final pillars = [
    aadhaarVerified ? 1.2 : 0.0,
    panVerified     ? 0.8 : 0.0,
    bankVerified    ? 1.5 : 0.0,
    itrVerified     ? 0.4 : 0.0,
    healthInsurance ? 0.3 : 0.0,
    workProofVerified ? 1.1 : 0.0,
    svanidhiVerified  ? 0.5 : 0.0,
    1.0 - debtToIncomeRatio,
  ];

  final coeffs = [1.2, 0.8, 1.5, 0.4, -0.6, 2.1, 0.3, 1.1];
  for (var i = 0; i < pillars.length; i++) {
    logit += pillars[i] * coeffs[i];
  }

  final prob  = 1.0 / (1.0 + exp(-logit));
  return (300 + prob * 600).round().clamp(300, 900);
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  final score     = computeScore();
  final riskColor = score >= 700 ? PdfColors.green800
      : score >= 550              ? PdfColors.orange800
      :                             PdfColors.red800;
  final riskBgColor = score >= 700 ? PdfColors.green50
      : score >= 550               ? PdfColors.orange50
      :                              PdfColors.red50;

  stdout.writeln('--- GigCredit Demo Report Generator ---');
  stdout.writeln('Applicant : $applicantName');
  stdout.writeln('Score     : $score / 900');
  stdout.writeln('Risk Band : $riskBand');
  stdout.writeln('Generating PDF...');

  final doc = pw.Document();

  // Use built-in PDF fonts only (no internet needed)
  final bold    = pw.Font.timesBoldItalic();
  final regular = pw.Font.times();
  final theme   = pw.ThemeData.withFont(base: regular, bold: bold);

  doc.addPage(pw.MultiPage(
    theme: theme,
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      _header(),
      pw.SizedBox(height: 20),
      _scoreCard(score, riskColor, riskBgColor),
      pw.SizedBox(height: 16),
      _section9Steps(),
      pw.SizedBox(height: 16),
      _driversSection(),
      pw.SizedBox(height: 16),
      _disclaimer(),
    ],
  ));

  final bytes = await doc.save();
  final outPath = 'C:/Users/PRAVEEN/Desktop/GigCredit_Demo_Report.pdf';
  File(outPath).writeAsBytesSync(bytes);

  stdout.writeln('SUCCESS! PDF saved to: $outPath');
  stdout.writeln('File size: ${bytes.length} bytes');
}

// ─────────────────────────────────────────────────────────────────────────────

pw.Widget _header() {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo700, width: 2)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('GigCredit',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: PdfColors.indigo800)),
            pw.Text('AI4Good Initiative',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Credit Assessment Report',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.indigo600)),
            pw.Text('Generated: ${_fmt(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _scoreCard(int score, PdfColor riskColor, PdfColor riskBgColor) {
  final fraction = ((score - 300) / 600).clamp(0.0, 1.0);

  return pw.Container(
    padding: const pw.EdgeInsets.all(18),
    decoration: pw.BoxDecoration(
      color: PdfColors.indigo50,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      border: pw.Border.all(color: PdfColors.indigo200),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Applicant', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(applicantName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.indigo900)),
        pw.Text('$workType  |  Age: $age  |  State: $state',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Credit Score',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('$score',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 52,
                      color: score >= 700 ? PdfColors.green700 : score >= 550 ? PdfColors.orange700 : PdfColors.red700)),
              pw.Text('Range 300 to 900',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ]),
            pw.SizedBox(width: 32),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Risk Band',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: riskBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(riskBand,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: riskColor)),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Monthly Income : INR ${monthlyIncome.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text('Monthly EMI    : INR ${monthlyEmi.toStringAsFixed(0)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              pw.Text('DTI Ratio      : ${(debtToIncomeRatio * 100).toStringAsFixed(1)}%',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ]),
          ],
        ),
        pw.SizedBox(height: 12),
        // Score bar
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Score Position',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 4),
            pw.Stack(children: [
              pw.Container(width: 500, height: 10,
                  decoration: pw.BoxDecoration(color: PdfColors.grey200,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)))),
              pw.Container(width: 500 * fraction, height: 10,
                  decoration: pw.BoxDecoration(
                      color: score >= 700 ? PdfColors.green600 : score >= 550 ? PdfColors.orange600 : PdfColors.red600,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)))),
            ]),
            pw.SizedBox(height: 3),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('300', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
              pw.Text('600', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
              pw.Text('900', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
            ]),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _section9Steps() {
  final steps = [
    ('Step 1', 'Basic Profile', 'Name, Age, Work Type, Dependents, State', true),
    ('Step 2', 'Identity (KYC)', 'Aadhaar verified, PAN verified, Face match ${(faceScore * 100).toStringAsFixed(0)}%', true),
    ('Step 3', 'Bank Verification', '$transactionCount transactions parsed, EMI pattern detected: $emiDetected', true),
    ('Step 4', 'Utility Bills', 'Electricity: $electricityVerified, Mobile: $mobileVerified, WiFi: $wifiVerified', electricityVerified),
    ('Step 5', 'Work Proof', 'Work document verified: $workProofVerified', workProofVerified),
    ('Step 6', 'Govt Schemes', 'SVANidhi: $svanidhiVerified, eShram: $eShramVerified', svanidhiVerified),
    ('Step 7', 'Insurance', 'Health: $healthInsurance, Life: $lifeInsurance, Vehicle: $vehicleInsurance', healthInsurance),
    ('Step 8', 'ITR / GST', 'ITR: $itrVerified | Annual Income: INR ${itrAnnualIncome.toStringAsFixed(0)} | GST: $gstVerified', itrVerified),
    ('Step 9', 'EMI / Loan Behavior', 'Monthly EMI INR ${monthlyEmi.toStringAsFixed(0)}, DTI ${(debtToIncomeRatio * 100).toStringAsFixed(1)}%, Loan API: $loanVerified', true),
  ];

  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColors.indigo100),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('9-Step Verification Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.indigo800)),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              children: [
                _th('Step'), _th('Section'), _th('Verified Data'), _th('Status'),
              ],
            ),
            ...steps.map((s) => pw.TableRow(
              children: [
                _td(s.$1), _td(s.$2), _td(s.$3),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(s.$4 ? 'PASS' : 'SKIP',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 8,
                          color: s.$4 ? PdfColors.green700 : PdfColors.orange700)),
                ),
              ],
            )),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _driversSection() {
  const positives = [
    'Strong Aadhaar and PAN verification quality',
    'Active bank ledger with 420 transactions',
    'Government scheme enrollment (SVANidhi, eShram)',
    'Consistent ITR compliance (INR 3.2 Lakh annual)',
    'Health and vehicle insurance continuity',
    'Low debt-to-income ratio (10.9%)',
    'Work proof document successfully verified',
  ];
  const concerns = [
    'GST compliance not yet registered',
    'Life insurance coverage gap identified',
    'WiFi utility verification pending',
    'Income relies predominantly on gig-platform receipts',
  ];

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: _driversBox('Positive Drivers', positives, PdfColors.green600, PdfColors.green50)),
      pw.SizedBox(width: 12),
      pw.Expanded(child: _driversBox('Areas of Concern', concerns, PdfColors.red600, PdfColors.red50)),
    ],
  );
}

pw.Widget _driversBox(String title, List<String> items, PdfColor accent, PdfColor bg) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: bg,
      border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: accent)),
        pw.SizedBox(height: 6),
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 5, height: 5,
              margin: const pw.EdgeInsets.only(top: 3, right: 6),
              decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
            ),
            pw.Expanded(child: pw.Text(item, style: const pw.TextStyle(fontSize: 9))),
          ]),
        )),
      ],
    ),
  );
}

pw.Widget _disclaimer() {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Text(
      'DISCLAIMER: This report is generated from simulated on-device verified gig-worker data for demonstration purposes. '
      'GigCredit AI4Good does not guarantee any lending decision. Score is indicative only. '
      'Report Language: English  |  Model: LR Meta-Learner v1 (Synthetic-Prod Coefficients)',
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
    ),
  );
}

// Helpers
pw.Widget _th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white)));

pw.Widget _td(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)));

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

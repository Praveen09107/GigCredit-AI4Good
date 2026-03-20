import 'dart:io';
import 'dart:developer' as developer;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/credit_report.dart';
import '../models/enums/report_language.dart';

/// Real PDF report generator using the `pdf` package.
/// Produces a proper A4 multi-section credit report PDF.
class ReportExportService {
  /// Build PDF bytes for [report].
  Future<List<int>> buildPdfBytes(CreditReport report) async {
    final doc = pw.Document(
      title: 'GigCredit Report — ${report.profileName}',
      author: 'GigCredit AI4Good',
      creator: 'GigCredit v0.1.0',
    );

    pw.Font? baseFont;
    pw.Font? boldFont;
    final isFlutterTest = Platform.environment['FLUTTER_TEST'] == 'true';

    baseFont = await _tryLoadSystemFont(const [
        r'C:\Windows\Fonts\segoeui.ttf',
        r'C:\Windows\Fonts\arial.ttf',
      ]);
    boldFont = await _tryLoadSystemFont(const [
        r'C:\Windows\Fonts\segoeuib.ttf',
        r'C:\Windows\Fonts\arialbd.ttf',
      ]);

    // Remote font downloads can stall in constrained CI/test networks.
    if (!isFlutterTest && (baseFont == null || boldFont == null)) {
      baseFont ??= await _tryLoadGoogleFontWithTimeout(PdfGoogleFonts.notoSansRegular);
      boldFont ??= await _tryLoadGoogleFontWithTimeout(PdfGoogleFonts.notoSansBold);
    }

    if (!isFlutterTest && (baseFont == null || boldFont == null)) {
      baseFont ??= await _tryLoadGoogleFontWithTimeout(PdfGoogleFonts.interRegular);
      boldFont ??= await _tryLoadGoogleFontWithTimeout(PdfGoogleFonts.interBold);
    }

    if (baseFont == null || boldFont == null) {
      baseFont = pw.Font.helvetica();
      boldFont = pw.Font.helveticaBold();
    }

    final theme = pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(context, report),
        footer: (context) => _buildFooter(context, report),
        build: (context) => <pw.Widget>[
          _scoreSection(report),
          pw.SizedBox(height: 16),
          _summarySection(report),
          pw.SizedBox(height: 16),
          _driversSection(report),
          pw.SizedBox(height: 16),
          _disclaimerSection(),
        ],
      ),
    );

    final bytes = await doc.save();
    developer.log('ReportExportService: generated ${bytes.length} byte PDF for ${report.profileName}');
    return bytes;
  }

  // ── Header ────────────────────────────────────────────────────────────────

  pw.Widget _buildHeader(pw.Context context, CreditReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
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
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                      color: PdfColors.indigo800)),
              pw.Text('AI4Good Initiative',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Text(
            'Credit Assessment Report',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.indigo600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context, CreditReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated: ${_formatDate(report.generatedAt)}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  // ── Score Section ─────────────────────────────────────────────────────────

  pw.Widget _scoreSection(CreditReport report) {
    final scoreColor = _scoreColor(report.score);

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Applicant', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text(report.profileName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Credit Score',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(
                    '${report.score}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 48,
                        color: scoreColor),
                  ),
                  pw.Text('Range: 300-900',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                ],
              ),
              pw.SizedBox(width: 32),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Risk Band',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: _riskBandBg(report.riskBand),
                    ),
                    child: pw.Text(
                      report.riskBand.toUpperCase(),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: _riskBandFg(report.riskBand)),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Report Language: ${report.language.label}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _scoreBar(report.score),
        ],
      ),
    );
  }

  pw.Widget _scoreBar(int score) {
    final fraction = ((score - 300) / 600).clamp(0.0, 1.0);
    // A4 content width ≈ 530pt (A4 595 - 32*2 margins)
    const double contentWidth = 530;
    final fillWidth = contentWidth * fraction;

    final bar = pw.Stack(
      children: [
        pw.Container(
          width: contentWidth,
          height: 8,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
        ),
        pw.Container(
          width: fillWidth,
          height: 8,
          decoration: pw.BoxDecoration(
            color: _scoreColor(score),
          ),
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Score Position', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        bar,
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('300', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('600', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('900', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    );
  }

  // ── Summary Section ───────────────────────────────────────────────────────

  pw.Widget _summarySection(CreditReport report) {
    return _section(
      title: 'Assessment Summary',
      child: pw.Text(
        report.summary,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
      ),
    );
  }

  // ── Drivers Section ───────────────────────────────────────────────────────

  pw.Widget _driversSection(CreditReport report) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _section(
            title: 'Positive Factors',
            borderColor: PdfColors.green600,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: report.positives.map((p) => _bullet(p, PdfColors.green700)).toList(),
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _section(
            title: 'Areas of Concern',
            borderColor: PdfColors.red500,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: report.concerns.map((c) => _bullet(c, PdfColors.red600)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Disclaimer ────────────────────────────────────────────────────────────

  pw.Widget _disclaimerSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
      ),
      child: pw.Text(
        'This report is generated from on-device verified data and is for informational purposes only. '
        'GigCredit AI4Good does not guarantee lending approval. Score is indicative.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  pw.Widget _section({
    required String title,
    required pw.Widget child,
    PdfColor borderColor = PdfColors.indigo400,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border(left: pw.BorderSide(color: borderColor, width: 3)),
        boxShadow: const [
          pw.BoxShadow(color: PdfColors.grey200, blurRadius: 4, offset: PdfPoint(0, 2)),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  pw.Widget _bullet(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 6,
            height: 6,
            margin: const pw.EdgeInsets.only(top: 3, right: 8),
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  PdfColor _scoreColor(int score) {
    if (score >= 750) return PdfColors.green700;
    if (score >= 650) return PdfColors.lightGreen700;
    if (score >= 550) return PdfColors.orange700;
    if (score >= 450) return PdfColors.deepOrange700;
    return PdfColors.red700;
  }

  PdfColor _riskBandBg(String band) {
    switch (band.toUpperCase()) {
      case 'LOW': return PdfColors.green50;
      case 'MEDIUM': return PdfColors.orange50;
      case 'HIGH': return PdfColors.red50;
      default: return PdfColors.grey100;
    }
  }

  PdfColor _riskBandFg(String band) {
    switch (band.toUpperCase()) {
      case 'LOW': return PdfColors.green800;
      case 'MEDIUM': return PdfColors.orange800;
      case 'HIGH': return PdfColors.red800;
      default: return PdfColors.grey700;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<pw.Font?> _tryLoadSystemFont(List<String> candidates) async {
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      try {
        final bytes = await file.readAsBytes();
        return pw.Font.ttf(bytes.buffer.asByteData());
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<pw.Font?> _tryLoadGoogleFontWithTimeout(
    Future<pw.Font> Function() loader,
  ) async {
    try {
      return await loader().timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }
}

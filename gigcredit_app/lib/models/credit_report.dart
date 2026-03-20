import 'enums/report_language.dart';

class CreditReport {
  const CreditReport({
    required this.profileName,
    required this.score,
    required this.riskBand,
    required this.summary,
    required this.positives,
    required this.concerns,
    required this.generatedAt,
    required this.language,
  });

  final String profileName;
  final int score;
  final String riskBand;
  final String summary;
  final List<String> positives;
  final List<String> concerns;
  final DateTime generatedAt;
  final ReportLanguage language;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';
import '../core/security/request_signer.dart';
import '../models/credit_report.dart';
import '../models/enums/report_language.dart';
import '../models/enums/step_status.dart';
import '../models/enums/work_type.dart';
import '../models/verified_profile.dart';
import '../scoring/scoring_engine.dart';
import '../scoring/scoring_pipeline.dart';
import '../scoring/shap_lookup_service.dart';
import '../services/backend_client.dart';
import '../services/report_export_service.dart';

class ReportState {
  const ReportState({
    this.selectedLanguage = ReportLanguage.english,
    this.isLoading = false,
    this.report,
    this.error,
    this.lastPdfBytes,
  });

  final ReportLanguage selectedLanguage;
  final bool isLoading;
  final CreditReport? report;
  final String? error;
  final List<int>? lastPdfBytes;

  ReportState copyWith({
    ReportLanguage? selectedLanguage,
    bool? isLoading,
    CreditReport? report,
    String? error,
    bool clearError = false,
    List<int>? lastPdfBytes,
  }) {
    return ReportState(
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isLoading: isLoading ?? this.isLoading,
      report: report ?? this.report,
      error: clearError ? null : (error ?? this.error),
      lastPdfBytes: lastPdfBytes ?? this.lastPdfBytes,
    );
  }
}

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>(
  (ref) => ReportNotifier(
    exportService: ReportExportService(),
    shapLookupService: ShapLookupService(),
  ),
);

class ReportNotifier extends StateNotifier<ReportState> {
  static const String _apiBaseUrl = String.fromEnvironment('GIGCREDIT_API_BASE_URL');
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');

  ReportNotifier({
    required ReportExportService exportService,
    required ShapLookupService shapLookupService,
  })
      : _exportService = exportService,
        _shapLookupService = shapLookupService,
        _scoringEngine = ScoringEngine(),
        super(const ReportState());

  final ReportExportService _exportService;
  final ShapLookupService _shapLookupService;
  final ScoringEngine _scoringEngine;

  String get _effectiveBaseUrl => _apiBaseUrl.isNotEmpty ? _apiBaseUrl : AppMode.resolvedBackendBaseUrl;

  void setLanguage(ReportLanguage language) {
    state = state.copyWith(selectedLanguage: language);
  }

  Future<void> generateFromProfile(VerifiedProfile profile) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));

      if (AppMode.requireProductionReadiness && !_productionWorkflowReady(profile)) {
        throw StateError('All verification workflow steps must be completed before scoring in production mode.');
      }

      final vector95 = const ScoringPipeline().buildSanitizedVector95(profile);
      final scoreOutcome = await _scoringEngine.score(
        rawFeatures: vector95,
        minimumGatePassed: _minimumGateSatisfied(profile),
        workTypeIndex: profile.workType?.metaIndex ?? 0,
      );
      if (!scoreOutcome.eligible) {
        throw StateError('Minimum scoring gate not satisfied.');
      }

      final explanation = await _shapLookupService.explainAsync(
        profile,
        featureVector95: vector95,
      );
      final report = await _buildReport(profile, scoreOutcome, explanation);

      state = state.copyWith(isLoading: false, report: report, clearError: true);
    } catch (error) {
      String message = 'Failed to generate report.';
      if (error is StateError) {
        final detail = error.message.toString().toLowerCase();
        final minimumDataGate =
            detail.contains('minimum') || detail.contains('insufficient') || detail.contains('step');
        message = minimumDataGate
            ? 'Insufficient data for credit assessment. Please complete Steps 1–3.'
            : 'Explainability data is unavailable for production-safe report generation.';
      }
      state = state.copyWith(isLoading: false, error: message);
    }
  }

  Future<void> exportPdf() async {
    final report = state.report;
    if (report == null) {
      state = state.copyWith(error: 'No report available to export.');
      return;
    }

    final bytes = await _exportService.buildPdfBytes(report);
    state = state.copyWith(lastPdfBytes: bytes, clearError: true);
  }

  bool _minimumGateSatisfied(VerifiedProfile p) {
    return p.aadhaarVerified &&
        p.panVerified &&
        p.bankVerified &&
        p.transactionCount >= 30;
  }

  bool _productionWorkflowReady(VerifiedProfile p) {
    if (p.verificationState.isEmpty) {
      return false;
    }
    for (final entry in p.verificationState.entries) {
      if (entry.value != StepStatus.verified) {
        return false;
      }
    }
    return true;
  }

  String _riskBandLabel(String riskBand) {
    switch (riskBand.toLowerCase()) {
      case 'high':
        return 'High Risk';
      case 'medium':
        return 'Medium Risk';
      case 'low':
        return 'Low Risk';
      default:
        return 'Unknown';
    }
  }

  Future<CreditReport> _buildReport(
    VerifiedProfile profile,
    ScoringOutcome scoreOutcome,
    dynamic explanation,
  ) async {
    final backendReport = await _generateBackendReport(profile, scoreOutcome, explanation);
    if (backendReport != null) {
      return backendReport;
    }

    return CreditReport(
      profileName: profile.fullName.isEmpty ? 'Applicant' : profile.fullName,
      score: scoreOutcome.finalScore,
      riskBand: _riskBandLabel(scoreOutcome.riskBand),
      summary: _summaryForLanguage(state.selectedLanguage, scoreOutcome.finalScore),
      positives: _localizeDrivers(explanation.positiveDriverKeys, state.selectedLanguage),
      concerns: _localizeDrivers(explanation.negativeDriverKeys, state.selectedLanguage),
      generatedAt: DateTime.now(),
      language: state.selectedLanguage,
    );
  }

  Future<CreditReport?> _generateBackendReport(
    VerifiedProfile profile,
    ScoringOutcome scoreOutcome,
    dynamic explanation,
  ) async {
    if (_effectiveBaseUrl.isEmpty || _apiKey.isEmpty) {
      return null;
    }

    try {
      final client = BackendClient(
        baseUrl: _effectiveBaseUrl,
        apiKey: _apiKey,
        deviceId: 'dev_b_report',
        signatureProvider: signatureProviderFromApiKey(_apiKey),
      );

      final payload = <String, dynamic>{
        'request_id': profile.phoneNumber.isEmpty ? 'anonymous' : profile.phoneNumber,
        'language': state.selectedLanguage.code,
        'score': scoreOutcome.finalScore.toDouble(),
        'pillars': scoreOutcome.pillarScores,
        'shap_factors': <Map<String, dynamic>>[
          ...explanation.positiveDriverKeys.map(
            (key) => <String, dynamic>{
              'key': key,
              'label': _labelForDriver(key, state.selectedLanguage),
              'value': (explanation.driverImpacts[key] ?? 0.0).abs(),
              'direction': 'positive',
            },
          ),
          ...explanation.negativeDriverKeys.map(
            (key) => <String, dynamic>{
              'key': key,
              'label': _labelForDriver(key, state.selectedLanguage),
              'value': (explanation.driverImpacts[key] ?? 0.0).abs(),
              'direction': 'negative',
            },
          ),
        ],
      };

      final response = await client.generateReport(payload);
      final status = response.status.toUpperCase();
      if (status != 'SUCCESS' && status != 'OK' && status != 'FOUND') {
        return null;
      }

      final data = response.data ?? const <String, dynamic>{};
        final backendScore = (data['score'] as num?)?.toInt() ?? scoreOutcome.finalScore;
        final backendRiskBand = _riskBandLabel(scoreOutcome.riskBand);
        final backendSummary =
          (data['explanation'] as String?) ?? (data['summary'] as String?) ?? _summaryForLanguage(state.selectedLanguage, backendScore);
        final suggestionList = _toStringList(data['suggestions']);

      return CreditReport(
        profileName: profile.fullName.isEmpty ? 'Applicant' : profile.fullName,
        score: backendScore,
        riskBand: backendRiskBand,
        summary: backendSummary,
        positives: _localizeDrivers(explanation.positiveDriverKeys, state.selectedLanguage),
        concerns: suggestionList.isEmpty
          ? _localizeDrivers(explanation.negativeDriverKeys, state.selectedLanguage)
          : suggestionList,
        generatedAt: DateTime.now(),
        language: state.selectedLanguage,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _toStringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  String _summaryForLanguage(ReportLanguage language, int score) {
    switch (language) {
      case ReportLanguage.english:
        return 'Your profile has been assessed using verified onboarding data.';
      case ReportLanguage.hindi:
        return 'आपकी प्रोफ़ाइल का मूल्यांकन सत्यापित डेटा के आधार पर किया गया है।';
      case ReportLanguage.tamil:
        return 'உங்கள் சுயவிவரம் சரிபார்க்கப்பட்ட தரவின் அடிப்படையில் மதிப்பிடப்பட்டது.';
    }
  }

  List<String> _localizeDrivers(List<String> keys, ReportLanguage language) {
    final labels = keys.map((key) => _labelForDriver(key, language)).toList(growable: false);
    return labels.isEmpty ? <String>[_labelForDriver('no_signal', language)] : labels;
  }

  String _labelForDriver(String key, ReportLanguage language) {
    switch (language) {
      case ReportLanguage.hindi:
        return _driverHindi[key] ?? 'पर्याप्त सिग्नल उपलब्ध नहीं';
      case ReportLanguage.tamil:
        return _driverTamil[key] ?? 'போதுமான சிக்னல்கள் இல்லை';
      case ReportLanguage.english:
        return _driverEnglish[key] ?? 'No significant driver identified';
    }
  }

  static const Map<String, String> _driverEnglish = <String, String>{
    'bank_verified': 'Bank verification strength',
    'pan_verified': 'PAN verification quality',
    'aadhaar_verified': 'Aadhaar verification quality',
    'itr_verified': 'ITR compliance signal',
    'gst_verified': 'GST compliance signal',
    'insurance_verified': 'Insurance continuity signal',
    'work_verified': 'Work proof consistency',
    'utility_coverage': 'Utility payment consistency',
    'scheme_enrollment': 'Government scheme continuity',
    'high_emi_burden': 'High EMI burden',
    'no_face_verify': 'Face verification missing',
    'no_work_proof': 'Work proof missing',
    'high_dti': 'Debt-to-income pressure',
    'no_tax_docs': 'Missing tax documents',
    'low_transaction_depth': 'Low transaction history depth',
    'no_signal': 'No significant driver identified',
  };

  static const Map<String, String> _driverHindi = <String, String>{
    'bank_verified': 'बैंक सत्यापन मजबूत है',
    'pan_verified': 'PAN सत्यापन मजबूत है',
    'aadhaar_verified': 'आधार सत्यापन मजबूत है',
    'itr_verified': 'ITR अनुपालन सकारात्मक है',
    'gst_verified': 'GST अनुपालन सकारात्मक है',
    'insurance_verified': 'बीमा निरंतरता सकारात्मक है',
    'work_verified': 'कार्य प्रमाण सुसंगत है',
    'utility_coverage': 'उपयोगिता भुगतान सुसंगत है',
    'scheme_enrollment': 'सरकारी योजना निरंतरता सकारात्मक है',
    'high_emi_burden': 'ईएमआई भार अधिक है',
    'no_face_verify': 'चेहरा सत्यापन उपलब्ध नहीं है',
    'no_work_proof': 'कार्य प्रमाण उपलब्ध नहीं है',
    'high_dti': 'ऋण-आय अनुपात दबाव में है',
    'no_tax_docs': 'कर दस्तावेज़ उपलब्ध नहीं हैं',
    'low_transaction_depth': 'लेनदेन इतिहास कम है',
    'no_signal': 'कोई प्रमुख ड्राइवर नहीं मिला',
  };

  static const Map<String, String> _driverTamil = <String, String>{
    'bank_verified': 'வங்கி சரிபார்ப்பு வலிமை',
    'pan_verified': 'PAN சரிபார்ப்பு தரம்',
    'aadhaar_verified': 'ஆதார் சரிபார்ப்பு தரம்',
    'itr_verified': 'ITR இணக்கம் நல்ல சிக்னல்',
    'gst_verified': 'GST இணக்கம் நல்ல சிக்னல்',
    'insurance_verified': 'காப்பீட்டு தொடர்ச்சி நல்ல சிக்னல்',
    'work_verified': 'வேலை சான்று நிலைத்தன்மை',
    'utility_coverage': 'பயன்பாட்டு கட்டண நிலைத்தன்மை',
    'scheme_enrollment': 'அரசுத் திட்ட தொடர்ச்சி',
    'high_emi_burden': 'EMI சுமை அதிகம்',
    'no_face_verify': 'முக சரிபார்ப்பு இல்லை',
    'no_work_proof': 'வேலை சான்று இல்லை',
    'high_dti': 'கடன்-வருமான அழுத்தம் அதிகம்',
    'no_tax_docs': 'வரி ஆவணங்கள் இல்லை',
    'low_transaction_depth': 'பரிவர்த்தனை வரலாறு குறைவு',
    'no_signal': 'முக்கிய சிக்னல் இல்லை',
  };
}

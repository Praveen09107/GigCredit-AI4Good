import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:math';
import 'dart:typed_data';

import '../models/enums/document_type.dart';
import '../config/app_mode.dart';
import 'ai_native_bridge.dart';
import 'ai_interfaces.dart';
import 'field_extractors.dart';
import 'ocr_engine.dart';
import 'secure_cleanup_policy.dart';
import 'transaction_engine.dart';
import 'verification_validation_engine.dart';

class NativeChannelOcrEngine implements OcrEngine {
  const NativeChannelOcrEngine({required this.bridge});

  final NativeAiBridge bridge;
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  @override
  Future<OcrResult> extractText(List<int> imageBytes) async {
    try {
      final health = await bridge.getHealth();
      if (!health.supportsOcr) {
        return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
      }
    } on NativeBridgeException {
      return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
    }

    try {
      return await bridge.extractText(
        imageBytes,
        meta: {
          'source': 'native_channel_ocr_engine',
          'byteCount': imageBytes.length,
          'meanIntensity': _mean(imageBytes),
          'entropyLike': _entropyLikeScore(imageBytes),
        },
      );
    } on NativeBridgeException {
      return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
    }
  }
}

class NativeChannelAuthenticityDetector implements AuthenticityDetector {
  const NativeChannelAuthenticityDetector({required this.bridge});

  final NativeAiBridge bridge;
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  @override
  Future<AuthenticityResult> detect(List<int> imageBytes) async {
    try {
      final health = await bridge.getHealth();
      if (!health.supportsAuthenticity) {
        return const AuthenticityResult(
          label: AuthenticityLabel.suspicious,
          confidence: 0.0,
        );
      }
    } on NativeBridgeException {
      return const AuthenticityResult(
        label: AuthenticityLabel.suspicious,
        confidence: 0.0,
      );
    }

    try {
      return await bridge.detectAuthenticity(imageBytes);
    } on NativeBridgeException {
      return const AuthenticityResult(
        label: AuthenticityLabel.suspicious,
        confidence: 0.0,
      );
    }
  }
}

class NativeChannelFaceVerifier implements FaceVerifier {
  const NativeChannelFaceVerifier({required this.bridge});

  final NativeAiBridge bridge;
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  @override
  Future<FaceMatchResult> matchFaces(
    List<int> selfieBytes,
    List<int> idBytes,
  ) async {
    try {
      final health = await bridge.getHealth();
      if (!health.supportsFaceMatch) {
        return const FaceMatchResult(similarity: 0.0, passed: false);
      }
    } on NativeBridgeException {
      return const FaceMatchResult(similarity: 0.0, passed: false);
    }

    try {
      return await bridge.matchFaces(selfieBytes, idBytes);
    } on NativeBridgeException {
      return const FaceMatchResult(similarity: 0.0, passed: false);
    }
  }
}

class HeuristicOcrEngine implements OcrEngine {
  const HeuristicOcrEngine();

  @override
  Future<OcrResult> extractText(List<int> imageBytes) async {
    final mean = _mean(imageBytes);
    final confidence = (0.60 + (mean / 255.0) * 0.35).clamp(0.60, 0.98);
    final extracted = _bestEffortTextFromBytes(imageBytes);
    return OcrResult(
      rawText: extracted.isEmpty ? 'OCR extraction unavailable for this document.' : extracted,
      confidence: confidence,
    );
  }
}

class HeuristicAuthenticityDetector implements AuthenticityDetector {
  const HeuristicAuthenticityDetector();

  @override
  Future<AuthenticityResult> detect(List<int> imageBytes) async {
    if (imageBytes.isEmpty) {
      return const AuthenticityResult(
        label: AuthenticityLabel.suspicious,
        confidence: 0.0,
      );
    }

    final entropyLikeScore = _entropyLikeScore(imageBytes);
    if (entropyLikeScore < 0.10) {
      return const AuthenticityResult(
        label: AuthenticityLabel.edited,
        confidence: 0.85,
      );
    }
    if (entropyLikeScore < 0.20) {
      return const AuthenticityResult(
        label: AuthenticityLabel.suspicious,
        confidence: 0.72,
      );
    }
    return const AuthenticityResult(
      label: AuthenticityLabel.real,
      confidence: 0.90,
    );
  }
}

class HeuristicFaceVerifier implements FaceVerifier {
  const HeuristicFaceVerifier();

  @override
  Future<FaceMatchResult> matchFaces(
    List<int> selfieBytes,
    List<int> idBytes,
  ) async {
    if (selfieBytes.isEmpty || idBytes.isEmpty) {
      return const FaceMatchResult(similarity: 0.0, passed: false);
    }

    final selfieVector = _signature(selfieBytes);
    final idVector = _signature(idBytes);
    final similarity = _cosineSimilarity(selfieVector, idVector);
    return FaceMatchResult(
      similarity: similarity,
      passed: similarity >= 0.78,
    );
  }
}

class NativeDocumentProcessor implements DocumentProcessor {
  const NativeDocumentProcessor({
    required this.ocrEngine,
    required this.authenticityDetector,
    this.validationEngine = const VerificationValidationEngine(),
    this.transactionEngine = const TransactionEngine(),
    this.cleanupPolicy = const SecureCleanupPolicy(),
  });

  final OcrEngine ocrEngine;
  final AuthenticityDetector authenticityDetector;
  final VerificationValidationEngine validationEngine;
  final TransactionEngine transactionEngine;
  final SecureCleanupPolicy cleanupPolicy;

  factory NativeDocumentProcessor.withDefaults() {
    final bridge = NativeAiBridge();
    return NativeDocumentProcessor(
      ocrEngine: BridgePaddleOcrEngine(bridge: bridge),
      authenticityDetector: NativeChannelAuthenticityDetector(bridge: bridge),
    );
  }

  @override
  Future<ProcessedDocument> process({
    required DocumentType documentType,
    required List<int> imageBytes,
  }) async {
    NativeRuntimeHealth? nativeHealth;
    try {
      nativeHealth = await (ocrEngine is BridgePaddleOcrEngine
          ? (ocrEngine as BridgePaddleOcrEngine).bridge.getHealth()
          : null);
    } on NativeBridgeException {
      nativeHealth = null;
    }

    final authenticity = await authenticityDetector.detect(imageBytes);
    final ocr = await ocrEngine.extractText(imageBytes);

    final fields = _extractFields(documentType, ocr.rawText, imageBytes);
    final validation = validationEngine.run(
      documentType: documentType,
      extractedFields: fields,
    );

    final metadata = <String, String>{
      'authenticity_label': authenticity.label.name,
      'authenticity_confidence': authenticity.confidence.toStringAsFixed(3),
      'ocr_confidence': ocr.confidence.toStringAsFixed(3),
      'ocr_low_confidence': (ocr.lowConfidence ?? false).toString(),
      'ocr_block_count': ocr.blocks.length.toString(),
      'validation_passed': validation.passed.toString(),
      'validation_issue_count': validation.issues.length.toString(),
      'native_runtime_ready': (nativeHealth?.ready ?? false).toString(),
      'native_engine_version': nativeHealth?.engineVersion ?? 'unavailable',
      'native_supports_ocr': (nativeHealth?.supportsOcr ?? false).toString(),
      'native_supports_authenticity':
          (nativeHealth?.supportsAuthenticity ?? false).toString(),
      'native_supports_face_match':
          (nativeHealth?.supportsFaceMatch ?? false).toString(),
    };

    if (documentType == DocumentType.bankStatement) {
      final txResult = transactionEngine.processBankStatementOcr(ocr.rawText);
      metadata['transaction_count'] = txResult.transactions.length.toString();
      metadata['active_emi_count'] = txResult.emiProfile.activeEmiCount.toString();
      metadata['total_monthly_emi'] = txResult.emiProfile.totalMonthlyEmi.toStringAsFixed(2);
      metadata['utility_debit_count'] = txResult.utilityDebitCount.toString();
      metadata['insurance_debit_count'] = txResult.insuranceDebitCount.toString();
      fields['bank_transactions_csv'] = txResult.csv;
    }

    return ProcessedDocument(
      documentType: documentType,
      ocr: ocr,
      authenticity: authenticity,
      fields: fields,
      validation: validation,
      metadata: metadata,
    );
  }

  Future<CleanupReport> secureCleanup({
    required List<String> rawArtifactPaths,
    List<List<int>> sensitiveBuffers = const <List<int>>[],
  }) {
    final buffers = sensitiveBuffers
        .map((value) => value is Uint8List ? value : Uint8List.fromList(value))
        .toList(growable: false);
    return cleanupPolicy.cleanup(
      rawArtifactPaths: rawArtifactPaths,
      inMemoryBuffers: buffers,
    );
  }

  Map<String, String> _extractFields(
    DocumentType type,
    String rawText,
    List<int> imageBytes,
  ) {
    final normalized = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final token = _tokenFromBytes(imageBytes);
    final parsed = FieldExtractors.parse(type, rawText);

    if (type == DocumentType.aadhaarFront || type == DocumentType.aadhaarBack) {
      final aadhaar = (parsed.fields['aadhaar_number'] ?? '').replaceAll(RegExp(r'\D'), '');
      final last4 = aadhaar.length >= 4
          ? aadhaar.substring(aadhaar.length - 4)
          : '';
      if (type == DocumentType.aadhaarFront) {
        return {
          'full_name': parsed.fields['name'] ?? '',
          'aadhaar_last4': last4,
          'ocr_summary': rawText,
        };
      }
      return {
        'address_line': parsed.fields['address'] ?? '',
        'state': _extractIndianState(normalized),
        'ocr_summary': rawText,
      };
    }

    if (type == DocumentType.pan) {
      return {
        'pan_number': (parsed.fields['pan_number'] ?? '').toUpperCase(),
        'full_name': parsed.fields['name'] ?? '',
        'ocr_summary': rawText,
      };
    }

    if (type == DocumentType.bankStatement) {
      return {
        'statement_id': parsed.fields['account_number']?.isNotEmpty == true
            ? parsed.fields['account_number']!
            : 'BS-$token',
        'account_holder_name': parsed.fields['name'] ?? '',
        'ifsc_code': parsed.fields['ifsc'] ?? '',
        'ocr_summary': rawText,
      };
    }

    if (type == DocumentType.electricityBill ||
        type == DocumentType.lpgBill ||
        type == DocumentType.mobileBill ||
        type == DocumentType.wifiBill) {
      final utilityId = parsed.fields['consumer_number']?.isNotEmpty == true
          ? parsed.fields['consumer_number']!
          : (parsed.fields['consumer_id']?.isNotEmpty == true
              ? parsed.fields['consumer_id']!
              : (parsed.fields['mobile_number'] ?? 'BILL-$token'));
      final amount = parsed.fields['bill_amount']?.isNotEmpty == true
          ? parsed.fields['bill_amount']!
          : (parsed.fields['amount'] ?? '');

      return {
        'bill_id': utilityId,
        'amount': amount,
        'payment_status': _inferPaymentStatus(normalized),
        'ocr_summary': rawText,
      };
    }

    switch (type) {
      case DocumentType.aadhaarFront:
      case DocumentType.aadhaarBack:
      case DocumentType.pan:
      case DocumentType.bankStatement:
      case DocumentType.electricityBill:
      case DocumentType.lpgBill:
      case DocumentType.mobileBill:
      case DocumentType.wifiBill:
        return {'ocr_summary': rawText};
      case DocumentType.rc:
        final vehicleNumber = _firstMatch(
          RegExp(r'\b[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{3,4}\b'),
          normalized.toUpperCase(),
        );
        return {
          'vehicle_number': vehicleNumber.isEmpty ? 'UNKNOWN' : vehicleNumber,
          'ocr_summary': rawText,
        };
      case DocumentType.insurance:
        final policyNumber = _firstMatch(
          RegExp(r'\b(?:policy\s*(?:no|number))\s*[:\-]?\s*([A-Z0-9\-]{6,})\b', caseSensitive: false),
          normalized,
          group: 1,
        );
        return {
          'policy_number': policyNumber.isEmpty ? 'UNKNOWN' : policyNumber,
          'status': normalized.toLowerCase().contains('active') ? 'ACTIVE' : 'UNKNOWN',
          'ocr_summary': rawText,
        };
      case DocumentType.governmentScheme:
        final labeledRef = _firstMatch(
          RegExp(
            r'\b(?:reference|ref|application|certificate|account|scheme|id)\s*(?:no|number|id)?\s*[:\-]?\s*([A-Z0-9\-]{6,30})\b',
            caseSensitive: false,
          ),
          normalized,
          group: 1,
        );
        final udyamRef = _firstMatch(
          RegExp(r'\bUDYAM-[A-Z]{2}-\d{2}-\d{7}\b', caseSensitive: false),
          normalized.toUpperCase(),
        );
        final fallbackRef = _firstMatch(
          RegExp(r'\b[A-Z0-9][A-Z0-9\-]{5,29}\b'),
          normalized.toUpperCase(),
        );
        final schemeReference = labeledRef.isNotEmpty
            ? labeledRef.toUpperCase()
            : (udyamRef.isNotEmpty ? udyamRef.toUpperCase() : (fallbackRef.isNotEmpty ? fallbackRef : 'UNKNOWN'));
        return {
          'scheme_reference': schemeReference,
          'ocr_summary': rawText,
        };
      case DocumentType.itr:
        final itrAck = _firstMatch(
          RegExp(r'\b(?:itr\s*(?:ack(?:nowledg(e)?ment)?\s*(?:no|number)?))\s*[:\-]?\s*([A-Z0-9\-]{6,})\b', caseSensitive: false),
          normalized,
          group: 2,
        );
        final annualIncome = _extractLargestAmount(normalized);
        final annualIncomeValue = double.tryParse(annualIncome.replaceAll(',', '')) ?? 0.0;
        final monthlyIncome = annualIncomeValue > 0 ? (annualIncomeValue / 12.0).toStringAsFixed(0) : '';
        return {
          'itr_ack_number': itrAck.isEmpty ? 'UNKNOWN' : itrAck,
          'annual_income': annualIncome,
          'monthly_income': monthlyIncome,
          'ocr_summary': rawText,
        };
    }
  }
}

String _firstMatch(RegExp pattern, String input, {int group = 0}) {
  final match = pattern.firstMatch(input);
  if (match == null) {
    return '';
  }
  return (match.group(group) ?? '').trim();
}

String _extractPersonName(String text) {
  final labeled = _firstMatch(
    RegExp(r'\b(?:name|account\s*holder|customer\s*name)\s*[:\-]?\s*([A-Z][A-Z\s\.]{2,40})\b', caseSensitive: false),
    text,
    group: 1,
  );
  if (labeled.isNotEmpty) {
    return labeled.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  final fallback = _firstMatch(RegExp(r'\b[A-Z][A-Z]+(?:\s+[A-Z][A-Z]+){1,3}\b'), text.toUpperCase());
  return fallback.isEmpty ? 'UNKNOWN' : fallback;
}

String _extractAddressLine(String text) {
  final labeled = _firstMatch(
    RegExp(r'\b(?:address|addr)\s*[:\-]?\s*([^\n]{8,120})\b', caseSensitive: false),
    text,
    group: 1,
  );
  return labeled.isEmpty ? 'UNKNOWN' : labeled;
}

String _extractIndianState(String text) {
  const states = <String>[
    'ANDHRA PRADESH',
    'ARUNACHAL PRADESH',
    'ASSAM',
    'BIHAR',
    'CHHATTISGARH',
    'GOA',
    'GUJARAT',
    'HARYANA',
    'HIMACHAL PRADESH',
    'JHARKHAND',
    'KARNATAKA',
    'KERALA',
    'MADHYA PRADESH',
    'MAHARASHTRA',
    'MANIPUR',
    'MEGHALAYA',
    'MIZORAM',
    'NAGALAND',
    'ODISHA',
    'PUNJAB',
    'RAJASTHAN',
    'SIKKIM',
    'TAMIL NADU',
    'TELANGANA',
    'TRIPURA',
    'UTTAR PRADESH',
    'UTTARAKHAND',
    'WEST BENGAL',
    'DELHI',
  ];

  final upper = text.toUpperCase();
  for (final state in states) {
    if (upper.contains(state)) {
      return state;
    }
  }
  return 'UNKNOWN';
}

String _extractLargestAmount(String text) {
  final matches = RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\b').allMatches(text);
  var best = '';
  var maxValue = 0.0;
  for (final match in matches) {
    final raw = match.group(0) ?? '';
    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed != null && parsed > maxValue) {
      maxValue = parsed;
      best = raw;
    }
  }
  return best;
}

String _inferPaymentStatus(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('paid') || lower.contains('completed') || lower.contains('success')) {
    return 'paid';
  }
  if (lower.contains('due') || lower.contains('pending')) {
    return 'due';
  }
  return 'unknown';
}

double _mean(List<int> bytes) {
  if (bytes.isEmpty) {
    return 0.0;
  }
  final sum = bytes.fold<int>(0, (acc, value) => acc + value);
  return sum / bytes.length;
}

double _entropyLikeScore(List<int> bytes) {
  if (bytes.length < 2) {
    return 0.0;
  }
  var changes = 0;
  for (var index = 1; index < bytes.length; index++) {
    if (bytes[index] != bytes[index - 1]) {
      changes += 1;
    }
  }
  return changes / (bytes.length - 1);
}

List<double> _signature(List<int> bytes) {
  const bins = 16;
  final histogram = List<double>.filled(bins, 0.0);
  if (bytes.isEmpty) {
    return histogram;
  }

  for (final value in bytes) {
    final bucket = (value * bins) ~/ 256;
    histogram[min(bucket, bins - 1)] += 1.0;
  }

  final norm = sqrt(histogram.fold<double>(0.0, (acc, value) => acc + value * value));
  if (norm == 0.0) {
    return histogram;
  }
  return histogram.map((value) => value / norm).toList();
}

double _cosineSimilarity(List<double> a, List<double> b) {
  var dot = 0.0;
  var na = 0.0;
  var nb = 0.0;
  for (var index = 0; index < a.length; index++) {
    dot += a[index] * b[index];
    na += a[index] * a[index];
    nb += b[index] * b[index];
  }
  if (na == 0.0 || nb == 0.0) {
    return 0.0;
  }
  return (dot / (sqrt(na) * sqrt(nb))).clamp(0.0, 1.0);
}

String _tokenFromBytes(List<int> bytes) {
  if (bytes.isEmpty) {
    return '000000';
  }
  final value = bytes.fold<int>(0, (acc, element) => ((acc * 31) + element) % 1000000);
  return value.toString().padLeft(6, '0');
}

String _bestEffortTextFromBytes(List<int> bytes) {
  if (bytes.isEmpty) {
    return '';
  }

  if (_looksLikePdf(bytes) && _isPasswordProtectedPdf(bytes)) {
    return kPasswordProtectedPdfMarker;
  }

  final pdfText = _extractPdfText(bytes);
  if (pdfText.isNotEmpty) {
    return pdfText;
  }

  final utf8Text = utf8.decode(bytes, allowMalformed: true).trim();
  if (_looksLikeReadableText(utf8Text)) {
    return utf8Text;
  }

  final latinText = latin1.decode(bytes, allowInvalid: true).trim();
  if (_looksLikeReadableText(latinText)) {
    return latinText;
  }

  return '';
}

String _extractPdfText(List<int> bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final out = StringBuffer();

  final directTextMatches = RegExp(r'\(([^\)]{3,})\)\s*Tj').allMatches(raw);
  for (final match in directTextMatches) {
    out.writeln(_decodePdfEscaped(match.group(1) ?? ''));
  }

  final streamRegex = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
  for (final match in streamRegex.allMatches(raw)) {
    final payloadText = match.group(1) ?? '';
    if (payloadText.isEmpty) {
      continue;
    }

    final streamBytes = Uint8List.fromList(payloadText.codeUnits.map((c) => c & 0xFF).toList());
    final inflated = _tryInflate(streamBytes);
    if (inflated == null || inflated.isEmpty) {
      continue;
    }

    final content = latin1.decode(inflated, allowInvalid: true);
    for (final tj in RegExp(r'\(([^\)]{2,})\)\s*Tj').allMatches(content)) {
      out.writeln(_decodePdfEscaped(tj.group(1) ?? ''));
    }
    for (final tjArray in RegExp(r'\[(.*?)\]\s*TJ').allMatches(content)) {
      final segment = tjArray.group(1) ?? '';
      for (final textToken in RegExp(r'\(([^\)]*)\)').allMatches(segment)) {
        final token = _decodePdfEscaped(textToken.group(1) ?? '');
        if (token.isNotEmpty) {
          out.write(token);
          out.write(' ');
        }
      }
      out.writeln();
    }
  }

  final normalized = out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return _looksLikeReadableText(normalized) ? normalized : '';
}

List<int>? _tryInflate(Uint8List input) {
  try {
    return zlib.decode(input);
  } catch (_) {
    return null;
  }
}

String _decodePdfEscaped(String value) {
  return value
      .replaceAll(r'\(', '(')
      .replaceAll(r'\)', ')')
      .replaceAll(r'\\', '\\')
      .replaceAll(r'\n', ' ')
      .replaceAll(r'\r', ' ')
      .trim();
}

bool _looksLikeReadableText(String text) {
  if (text.isEmpty || text.length < 16) {
    return false;
  }
  final printable = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
  return printable >= 8;
}

bool _looksLikePdf(List<int> bytes) {
  if (bytes.length < 4) {
    return false;
  }
  return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
}

bool _isPasswordProtectedPdf(List<int> bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Encrypt\b').hasMatch(raw) || RegExp(r'/Filter\s*/Standard\b').hasMatch(raw);
}

import 'dart:math';
import 'dart:typed_data';

import '../models/enums/document_type.dart';
import 'ai_native_bridge.dart';
import 'ai_interfaces.dart';
import 'secure_cleanup_policy.dart';
import 'transaction_engine.dart';
import 'verification_validation_engine.dart';

class NativeChannelOcrEngine implements OcrEngine {
  const NativeChannelOcrEngine({required this.bridge, required this.fallback});

  final NativeAiBridge bridge;
  final OcrEngine fallback;

  @override
  Future<OcrResult> extractText(List<int> imageBytes) async {
    try {
      final health = await bridge.getHealth();
      if (!health.supportsOcr) {
        return fallback.extractText(imageBytes);
      }
    } on NativeBridgeException {
      return fallback.extractText(imageBytes);
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
      return fallback.extractText(imageBytes);
    }
  }
}

class NativeChannelAuthenticityDetector implements AuthenticityDetector {
  const NativeChannelAuthenticityDetector({
    required this.bridge,
    required this.fallback,
  });

  final NativeAiBridge bridge;
  final AuthenticityDetector fallback;

  @override
  Future<AuthenticityResult> detect(List<int> imageBytes) async {
    try {
      final health = await bridge.getHealth();
      if (!health.supportsAuthenticity) {
        return fallback.detect(imageBytes);
      }
    } on NativeBridgeException {
      return fallback.detect(imageBytes);
    }

    try {
      return await bridge.detectAuthenticity(imageBytes);
    } on NativeBridgeException {
      return fallback.detect(imageBytes);
    }
  }
}

class NativeChannelFaceVerifier implements FaceVerifier {
  const NativeChannelFaceVerifier({
    required this.bridge,
    required this.fallback,
  });

  final NativeAiBridge bridge;
  final FaceVerifier fallback;

  @override
  Future<FaceMatchResult> matchFaces(
    List<int> selfieBytes,
    List<int> idBytes,
  ) async {
    try {
      final health = await bridge.getHealth();
      if (!health.supportsFaceMatch) {
        return fallback.matchFaces(selfieBytes, idBytes);
      }
    } on NativeBridgeException {
      return fallback.matchFaces(selfieBytes, idBytes);
    }

    try {
      return await bridge.matchFaces(selfieBytes, idBytes);
    } on NativeBridgeException {
      return fallback.matchFaces(selfieBytes, idBytes);
    }
  }
}

class HeuristicOcrEngine implements OcrEngine {
  const HeuristicOcrEngine();

  @override
  Future<OcrResult> extractText(List<int> imageBytes) async {
    final mean = _mean(imageBytes);
    final confidence = (0.60 + (mean / 255.0) * 0.35).clamp(0.60, 0.98);
    return OcrResult(
      rawText: 'OCR extracted text block (heuristic engine).',
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
    const fallbackOcr = HeuristicOcrEngine();
    const fallbackAuth = HeuristicAuthenticityDetector();
    final bridge = NativeAiBridge();
    return NativeDocumentProcessor(
      ocrEngine: NativeChannelOcrEngine(
        bridge: bridge,
        fallback: fallbackOcr,
      ),
      authenticityDetector: NativeChannelAuthenticityDetector(
        bridge: bridge,
        fallback: fallbackAuth,
      ),
    );
  }

  @override
  Future<ProcessedDocument> process({
    required DocumentType documentType,
    required List<int> imageBytes,
  }) async {
    NativeRuntimeHealth? nativeHealth;
    try {
      nativeHealth = await (ocrEngine is NativeChannelOcrEngine
          ? (ocrEngine as NativeChannelOcrEngine).bridge.getHealth()
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
    final token = _tokenFromBytes(imageBytes);
    switch (type) {
      case DocumentType.aadhaarFront:
        return {
          'full_name': 'Prototype User',
          'aadhaar_last4': token.substring(0, 4),
          'ocr_summary': rawText,
        };
      case DocumentType.aadhaarBack:
        return {
          'address_line': 'Prototype Address',
          'state': 'Karnataka',
          'ocr_summary': rawText,
        };
      case DocumentType.pan:
        return {
          'pan_number': 'ABCDE${token.substring(0, 4)}F',
          'full_name': 'Prototype User',
          'ocr_summary': rawText,
        };
      case DocumentType.bankStatement:
        return {
          'statement_id': 'BS-$token',
          'ocr_summary': rawText,
        };
      case DocumentType.electricityBill:
      case DocumentType.lpgBill:
      case DocumentType.mobileBill:
      case DocumentType.wifiBill:
        return {
          'bill_id': 'BILL-$token',
          'ocr_summary': rawText,
        };
      case DocumentType.rc:
        return {
          'vehicle_number': 'KA01${token.substring(0, 2)}${token.substring(2, 6)}',
          'ocr_summary': rawText,
        };
      case DocumentType.insurance:
        return {
          'policy_number': 'POL$token',
          'status': 'ACTIVE',
          'ocr_summary': rawText,
        };
      case DocumentType.itr:
        return {
          'itr_ack_number': 'ITR$token',
          'ocr_summary': rawText,
        };
    }
  }
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

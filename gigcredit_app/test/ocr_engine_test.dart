import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/ai_interfaces.dart';
import 'package:gigcredit_app/ai/ai_native_bridge.dart';
import 'package:gigcredit_app/ai/ocr_engine.dart';

class _FakeBridge extends NativeAiBridge {
  _FakeBridge({
    required this.health,
    this.primaryResult = const OcrResult(rawText: '', confidence: 0.0),
    this.secondaryResult,
    this.throwOnExtract = false,
    this.throwOnSecondary = false,
    this.extractDelay = Duration.zero,
  });

  final NativeRuntimeHealth health;
  final OcrResult primaryResult;
  final OcrResult? secondaryResult;
  final bool throwOnExtract;
  final bool throwOnSecondary;
  final Duration extractDelay;

  int extractCalls = 0;
  final List<String> passes = <String>[];

  @override
  Future<NativeRuntimeHealth> getHealth({bool forceRefresh = false}) async {
    return health;
  }

  @override
  Future<OcrResult> extractText(List<int> imageBytes, {Map<String, Object?>? meta}) async {
    if (extractDelay > Duration.zero) {
      await Future<void>.delayed(extractDelay);
    }
    if (throwOnExtract) {
      throw const NativeBridgeException('ocr_failed', 'simulated failure');
    }
    extractCalls += 1;
    final pass = (meta?['ocr_pass'] ?? '').toString();
    passes.add(pass);
    if (pass == 'secondary_regional') {
      if (throwOnSecondary) {
        throw const NativeBridgeException('ocr_secondary_failed', 'simulated secondary failure');
      }
      return secondaryResult ?? const OcrResult(rawText: '', confidence: 0.0);
    }
    return primaryResult;
  }
}

NativeRuntimeHealth _health({required bool supportsOcr}) {
  return NativeRuntimeHealth(
    ready: true,
    engineVersion: 'test',
    modelsLoaded: true,
    fetchedAt: DateTime(2026, 3, 20),
    ocrRuntimeAvailable: supportsOcr,
    tfliteRuntimeAvailable: true,
    authenticityModelAvailable: true,
    faceModelAvailable: true,
  );
}

void main() {
  group('BridgePaddleOcrEngine', () {
    test('runs secondary pass when primary is low confidence and merges complementary text', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(
          rawText: 'Invoice 123\nAmount 4500',
          confidence: 0.62,
          blocks: <OcrBlock>[
            OcrBlock(text: 'Invoice 123', confidence: 0.60),
            OcrBlock(text: 'Amount 4500', confidence: 0.64),
          ],
        ),
        secondaryResult: const OcrResult(
          rawText: 'Invoice 123\nDate 01/01/2026',
          confidence: 0.78,
          blocks: <OcrBlock>[
            OcrBlock(text: 'Invoice 123', confidence: 0.75),
            OcrBlock(text: 'Date 01/01/2026', confidence: 0.81),
          ],
        ),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: true,
      );

      final result = await engine.extractText(<int>[1, 2, 3, 4, 5]);

      expect(bridge.extractCalls, 2);
      expect(bridge.passes, containsAll(<String>['primary_english', 'secondary_regional']));
      expect(result.rawText, contains('Amount 4500'));
      expect(result.rawText, contains('Date 01/01/2026'));
      expect(result.confidence, greaterThanOrEqualTo(0.70));
      expect(result.lowConfidence, isTrue);
    });

    test('marks lowConfidence when score is below strict production threshold', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(
          rawText: 'Readable text but below strict threshold',
          confidence: 0.80,
        ),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: true,
      );

      final result = await engine.extractText(<int>[1, 2, 3]);

      expect(result.lowConfidence, isTrue);
      expect(result.confidence, lessThan(0.85));
    });

    test('keeps primary result when secondary pass fails', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(
          rawText: 'Primary text survives',
          confidence: 0.83,
        ),
        throwOnSecondary: true,
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: false,
      );

      final result = await engine.extractText(<int>[8, 8, 8]);

      expect(result.rawText, contains('Primary text survives'));
      expect(bridge.extractCalls, 2);
    });

    test('skips secondary pass when primary confidence is already high', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(
          rawText: 'PAN ABCDE1234F',
          confidence: 0.91,
        ),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: true,
      );

      final result = await engine.extractText(<int>[7, 8, 9]);

      expect(bridge.extractCalls, 1);
      expect(result.rawText, contains('ABCDE1234F'));
      expect(result.lowConfidence, isFalse);
    });

    test('returns marker for password-protected PDF before OCR calls', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(rawText: 'SHOULD_NOT_BE_USED', confidence: 0.9),
      );
      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: true,
      );

      final bytes = '%PDF-1.4\n/Encrypt 7 0 R\nobj'.codeUnits;
      final result = await engine.extractText(bytes);

      expect(result.rawText, kPasswordProtectedPdfMarker);
      expect(result.lowConfidence, isTrue);
      expect(bridge.extractCalls, 0);
    });

    test('fails closed when native OCR fails', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        throwOnExtract: true,
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: false,
      );

      final result = await engine.extractText(<int>[3, 2, 1]);

      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
      expect(result.lowConfidence, isTrue);
    });

    test('fails closed when native OCR times out', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        extractDelay: const Duration(milliseconds: 50),
        primaryResult: const OcrResult(rawText: 'late result', confidence: 0.88),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: false,
        primaryPassTimeout: const Duration(milliseconds: 1),
      );

      final result = await engine.extractText(<int>[9, 9, 9]);

      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
      expect(result.lowConfidence, isTrue);
    });

    test('fails closed in production mode when native OCR times out', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        extractDelay: const Duration(milliseconds: 50),
        primaryResult: const OcrResult(rawText: 'late result', confidence: 0.88),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: true,
        primaryPassTimeout: const Duration(milliseconds: 1),
      );

      final result = await engine.extractText(<int>[1, 1, 1]);

      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
      expect(result.lowConfidence, isTrue);
    });

    test('sanitizes control characters from OCR text', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(
          rawText: 'PAN\u0000  ABCDE1234F\r\n\r\nName\t\tRavi',
          confidence: 0.91,
        ),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: false,
      );

      final result = await engine.extractText(<int>[3, 4, 5]);

      expect(result.rawText, isNot(contains('\u0000')));
      expect(result.rawText, contains('ABCDE1234F'));
      expect(result.rawText, contains('Name Ravi'));
    });

    test('fails closed for oversized input in non-production mode', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
        primaryResult: const OcrResult(rawText: 'native should be skipped', confidence: 0.9),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: false,
      );

      final result = await engine.extractText(List<int>.filled(16 * 1024 * 1024, 1));

      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
      expect(result.lowConfidence, isTrue);
      expect(bridge.extractCalls, 0);
    });

    test('fails closed for oversized input in production mode', () async {
      final bridge = _FakeBridge(
        health: _health(supportsOcr: true),
      );

      final engine = BridgePaddleOcrEngine(
        bridge: bridge,
        requireProductionReadiness: true,
      );

      final result = await engine.extractText(List<int>.filled(16 * 1024 * 1024, 1));

      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
      expect(result.lowConfidence, isTrue);
      expect(bridge.extractCalls, 0);
    });
  });

  group('PdfTextStreamOcrEngine', () {
    test('returns marker for password-protected PDF', () async {
      const engine = PdfTextStreamOcrEngine();
      final bytes = '%PDF-1.7\n/Filter /Standard\n/Encrypt 2 0 R\n'.codeUnits;

      final result = await engine.extractText(bytes);

      expect(result.rawText, kPasswordProtectedPdfMarker);
      expect(result.lowConfidence, isTrue);
      expect(result.confidence, 0.0);
    });

    test('accepts direct PDF text stream when extracted text length is above threshold', () async {
      const engine = PdfTextStreamOcrEngine();
      final longText = List<String>.filled(25, 'transaction line').join(' ');
      final bytes = '%PDF-1.4\nBT\n($longText) Tj\nET\n'.codeUnits;

      final result = await engine.extractText(bytes);

      expect(result.rawText, contains('transaction line'));
      expect(result.confidence, 0.58);
      expect(result.lowConfidence, isTrue);
    });
  });
}

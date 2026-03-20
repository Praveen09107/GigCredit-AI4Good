import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/ai_interfaces.dart';
import 'package:gigcredit_app/ai/ai_native_bridge.dart';
import 'package:gigcredit_app/services/ondevice_ocr_service.dart';

class _FakeNativeBridge extends NativeAiBridge {
  _FakeNativeBridge({
    required this.health,
    this.ocrResult = const OcrResult(rawText: '', confidence: 0.0),
    this.throwOnHealth = false,
    this.throwOnExtract = false,
  });

  final NativeRuntimeHealth health;
  final OcrResult ocrResult;
  final bool throwOnHealth;
  final bool throwOnExtract;

  @override
  Future<NativeRuntimeHealth> getHealth({bool forceRefresh = false}) async {
    if (throwOnHealth) {
      throw const NativeBridgeException('health_failed', 'simulated health failure');
    }
    return health;
  }

  @override
  Future<OcrResult> extractText(List<int> imageBytes, {Map<String, Object?>? meta}) async {
    if (throwOnExtract) {
      throw const NativeBridgeException('ocr_failed', 'simulated ocr failure');
    }
    return ocrResult;
  }
}

Future<String> _writeTempFile(String name, List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('gigcredit_ocr_test_');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

NativeRuntimeHealth _health({required bool supportsOcr}) {
  return NativeRuntimeHealth(
    ready: true,
    engineVersion: 'test-runtime',
    modelsLoaded: true,
    fetchedAt: DateTime(2026, 3, 20),
    ocrRuntimeAvailable: supportsOcr,
    tfliteRuntimeAvailable: true,
    authenticityModelAvailable: true,
    faceModelAvailable: true,
  );
}

void main() {
  group('OnDeviceOcrService', () {
    test('returns missing_file when file does not exist', () async {
      const service = OnDeviceOcrService(requireProductionReadiness: true);

      final result = await service.extractFromFile(filePath: 'Z:/path/does/not/exist.pdf');

      expect(result.source, 'missing_file');
      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
    });

    test('prefers native OCR when runtime supports OCR and text is present', () async {
      final filePath = await _writeTempFile('doc.png', Uint8List.fromList(<int>[1, 2, 3, 4]));
      final service = OnDeviceOcrService(
        bridge: _FakeNativeBridge(
          health: _health(supportsOcr: true),
          ocrResult: const OcrResult(
            rawText: 'PAN ABCDE1234F NAME Ravi Kumar',
            confidence: 0.93,
          ),
        ),
        requireProductionReadiness: true,
      );

      final result = await service.extractFromFile(filePath: filePath, docHint: 'pan');

      expect(result.source, 'native_bridge');
      expect(result.rawText, contains('ABCDE1234F'));
      expect(result.confidence, 0.93);
      expect(result.hasUsableText, isTrue);
    });

    test('uses local on-device fallback when native OCR unavailable in non-production mode', () async {
      final fallbackText = 'Invoice number INV-99999 amount 1234 paid and valid text';
      final filePath = await _writeTempFile('doc.txt', fallbackText.codeUnits);
      final service = OnDeviceOcrService(
        bridge: _FakeNativeBridge(
          health: _health(supportsOcr: false),
        ),
        requireProductionReadiness: false,
      );

      final result = await service.extractFromFile(filePath: filePath, docHint: 'invoice');

      expect(result.source, 'local_pdf_text_stream');
      expect(result.rawText, contains('Invoice number'));
      expect(result.confidence, greaterThan(0.0));
    });

    test('returns native_required_unavailable when native extraction throws', () async {
      final pseudoImage = Uint8List.fromList(<int>[9, 8, 7, 6, 5]);
      final filePath = await _writeTempFile('statement.png', pseudoImage);
      final service = OnDeviceOcrService(
        bridge: _FakeNativeBridge(
          health: _health(supportsOcr: true),
          throwOnExtract: true,
        ),
        requireProductionReadiness: true,
      );

      final result = await service.extractFromFile(filePath: filePath, docHint: 'bank_statement');

      expect(result.source, 'native_required_unavailable');
      expect(result.rawText, isEmpty);
      expect(result.confidence, 0.0);
    });
  });
}

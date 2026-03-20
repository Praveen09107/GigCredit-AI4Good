import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:crypto/crypto.dart' as crypto;
import 'package:path_provider/path_provider.dart';

import '../ai/ai_native_bridge.dart';
import '../config/app_mode.dart';

class ModelBundleResult {
  const ModelBundleResult({
    required this.ok,
    required this.resolvedAssets,
    required this.resolvedLocalPaths,
    required this.failures,
    required this.checkedAt,
  });

  final bool ok;
  final Map<String, String> resolvedAssets;
  final Map<String, String> resolvedLocalPaths;
  final List<String> failures;
  final DateTime checkedAt;
}

class ModelBundleService {
  ModelBundleService({NativeAiBridge? bridge}) : _bridge = bridge ?? NativeAiBridge();

  final NativeAiBridge _bridge;

  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;
  static const int _minOcrModelBytes = 100 * 1024;
  static const int _minScoringModelBytes = 50 * 1024;

  static const Map<String, List<String>> _requiredAssetCandidates =
      <String, List<String>>{
    'ocr_model': <String>[
      'assets/models/ppocrv3_mobile_ocr.tflite',
      'assets/models/ocr_model.tflite',
    ],
    'scoring_model': <String>[
      'assets/models/scoring_meta.tflite',
      'assets/models/scoring_model.tflite',
      'assets/models/scoring_model_v1.tflite',
    ],
    'shap_lookup': <String>[
      'assets/constants/shap_lookup.json',
    ],
  };

  Future<ModelBundleResult> ensureBundledModelsReady() async {
    final checkedAt = DateTime.now();
    final resolvedAssets = <String, String>{};
    final resolvedLocalPaths = <String, String>{};
    final resolvedByteSizes = <String, int>{};
    final failures = <String>[];

    final supportDir = await getApplicationSupportDirectory();
    final modelRoot = Directory('${supportDir.path}${Platform.pathSeparator}model_bundle_v1');
    if (!await modelRoot.exists()) {
      await modelRoot.create(recursive: true);
    }

    for (final entry in _requiredAssetCandidates.entries) {
      final logicalName = entry.key;
      final candidates = entry.value;

      final loadedCandidates = <_LoadedAsset>[];
      for (final candidate in candidates) {
        try {
          loadedCandidates.add(
            _LoadedAsset(path: candidate, bytes: await rootBundle.load(candidate)),
          );
        } catch (_) {
          continue;
        }
      }

      if (loadedCandidates.isEmpty) {
        failures.add('Missing bundled asset for $logicalName');
        continue;
      }

      if (_requireProductionReadiness) {
        _validateCandidateSet(logicalName, loadedCandidates, failures);
      }

      final selected = _selectBestCandidate(logicalName, loadedCandidates);
      final bytes = selected.bytes;
      final assetPath = selected.path;

      resolvedAssets[logicalName] = assetPath;
      final byteList = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      resolvedByteSizes[logicalName] = byteList.length;
      final extension = assetPath.endsWith('.json') ? 'json' : 'tflite';
      final file = File(
        '${modelRoot.path}${Platform.pathSeparator}$logicalName.$extension',
      );

      if (!await file.exists()) {
        await file.writeAsBytes(byteList, flush: true);
      } else {
        final currentLen = await file.length();
        if (currentLen != byteList.length) {
          await file.writeAsBytes(byteList, flush: true);
        }
      }

      resolvedLocalPaths[logicalName] = file.path;
    }

    if (_requireProductionReadiness) {
      _validateResolvedModels(
        resolvedAssets: resolvedAssets,
        resolvedByteSizes: resolvedByteSizes,
        failures: failures,
      );

      if (!resolvedLocalPaths.containsKey('ocr_model')) {
        failures.add('Production mode requires bundled PP-OCRv3 Mobile model.');
      }
      final resolvedOcrAsset = resolvedAssets['ocr_model'];
      if (resolvedOcrAsset != 'assets/models/ppocrv3_mobile_ocr.tflite') {
        failures.add('Production mode requires assets/models/ppocrv3_mobile_ocr.tflite as the OCR model source.');
      }
      if (!resolvedLocalPaths.containsKey('scoring_model')) {
        failures.add('Production mode requires bundled scoring model.');
      }
    }

    if (resolvedLocalPaths.isNotEmpty) {
      await _bridge.configureModelPaths(resolvedLocalPaths);
    }

    return ModelBundleResult(
      ok: failures.isEmpty,
      resolvedAssets: Map<String, String>.unmodifiable(resolvedAssets),
      resolvedLocalPaths: Map<String, String>.unmodifiable(resolvedLocalPaths),
      failures: List<String>.unmodifiable(failures),
      checkedAt: checkedAt,
    );
  }

  _LoadedAsset _selectBestCandidate(String logicalName, List<_LoadedAsset> loaded) {
    if (loaded.length == 1) {
      return loaded.first;
    }

    final sorted = List<_LoadedAsset>.from(loaded)
      ..sort((a, b) => b.bytes.lengthInBytes.compareTo(a.bytes.lengthInBytes));

    // For model binaries, prefer the largest candidate to avoid selecting tiny placeholders.
    if (logicalName == 'ocr_model' || logicalName == 'scoring_model') {
      return sorted.first;
    }
    return loaded.first;
  }

  void _validateResolvedModels({
    required Map<String, String> resolvedAssets,
    required Map<String, int> resolvedByteSizes,
    required List<String> failures,
  }) {
    final ocrSize = resolvedByteSizes['ocr_model'] ?? 0;
    if (ocrSize > 0 && ocrSize < _minOcrModelBytes) {
      failures.add(
        'OCR model is too small for production readiness ($ocrSize bytes). Replace with real PP-OCRv3 Mobile TFLite.',
      );
    }

    final scoringSize = resolvedByteSizes['scoring_model'] ?? 0;
    if (scoringSize > 0 && scoringSize < _minScoringModelBytes) {
      failures.add(
        'Scoring model is too small for production readiness ($scoringSize bytes). Replace with real scoring TFLite.',
      );
    }

    final selectedOcr = resolvedAssets['ocr_model'];
    if (selectedOcr == 'assets/models/ocr_model.tflite') {
      failures.add('Production mode requires canonical OCR model asset: assets/models/ppocrv3_mobile_ocr.tflite.');
    }
  }

  void _validateCandidateSet(
    String logicalName,
    List<_LoadedAsset> loaded,
    List<String> failures,
  ) {
    if (logicalName != 'ocr_model') {
      return;
    }

    _LoadedAsset? ppocr;
    _LoadedAsset? alias;
    for (final item in loaded) {
      if (item.path == 'assets/models/ppocrv3_mobile_ocr.tflite') {
        ppocr = item;
      } else if (item.path == 'assets/models/ocr_model.tflite') {
        alias = item;
      }
    }

    if (ppocr == null || alias == null) {
      return;
    }

    final ppocrBytes = ppocr.bytes.buffer.asUint8List(ppocr.bytes.offsetInBytes, ppocr.bytes.lengthInBytes);
    final aliasBytes = alias.bytes.buffer.asUint8List(alias.bytes.offsetInBytes, alias.bytes.lengthInBytes);
    final ppocrHash = crypto.sha256.convert(ppocrBytes).toString();
    final aliasHash = crypto.sha256.convert(aliasBytes).toString();
    if (ppocrHash == aliasHash) {
      failures.add(
        'PP-OCR asset and legacy OCR alias are byte-identical. Replace with a real PP-OCR model and remove alias duplication for production.',
      );
    }
  }
}

class _LoadedAsset {
  const _LoadedAsset({required this.path, required this.bytes});

  final String path;
  final ByteData bytes;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../ai/ai_native_bridge.dart';
import '../services/model_bundle_service.dart';
import 'app_runtime_policy_provider.dart';
import 'model_bundle_provider.dart';
import 'native_runtime_provider.dart';

class StartupSelfCheckResult {
  const StartupSelfCheckResult({
    required this.productionRequired,
    required this.blocking,
    required this.failures,
    required this.checkedAt,
    this.health,
  });

  final bool productionRequired;
  final bool blocking;
  final List<String> failures;
  final DateTime checkedAt;
  final NativeRuntimeHealth? health;
}

final startupSelfCheckProvider = FutureProvider<StartupSelfCheckResult>((ref) async {
  final checkedAt = DateTime.now();
  final policy = ref.watch(appRuntimePolicyProvider);
  final productionRequired = policy.requireProductionReadiness;

  NativeRuntimeHealth? health;
  ModelBundleResult? bundleResult;
  try {
    health = await ref.watch(nativeRuntimeHealthProvider.future);
  } catch (_) {
    health = null;
  }

  try {
    bundleResult = await ref.watch(modelBundleProvider.future);
  } catch (_) {
    bundleResult = null;
  }

  final failures = <String>[];

  if (productionRequired) {
    if (policy.enforceBundledAssetChecks) {
      final requiredAssets = <String>[
        'assets/models/ppocrv3_mobile_ocr.tflite',
        'assets/models/scoring_meta.tflite',
        'assets/models/scoring_model.tflite',
        'assets/models/scoring_model_v1.tflite',
        'assets/constants/shap_lookup.json',
      ];
      for (final asset in requiredAssets) {
        if (!await _assetExists(asset)) {
          if (asset == 'assets/models/scoring_model_v1.tflite') {
            // Allow scoring_model.tflite as primary alias.
            continue;
          }
          failures.add('Required bundled asset missing: $asset');
        }
      }

      if (bundleResult == null) {
        failures.add('Model bundle bootstrap failed unexpectedly.');
      } else if (!bundleResult.ok) {
        failures.addAll(bundleResult.failures);
      }
    }

    if (health == null || health.ready != true) {
      failures.add('Native runtime is unavailable.');
    } else {
      // OCR is the only required on-device runtime capability.
      if (health.ocrRuntimeAvailable != true) {
        failures.add('OCR runtime/capability is unavailable (model/dependency missing).');
      }
    }
  }

  return StartupSelfCheckResult(
    productionRequired: productionRequired,
    blocking: productionRequired && failures.isNotEmpty,
    failures: failures,
    checkedAt: checkedAt,
    health: health,
  );
});

Future<bool> _assetExists(String assetPath) async {
  try {
    await rootBundle.load(assetPath);
    return true;
  } catch (_) {
    return false;
  }
}

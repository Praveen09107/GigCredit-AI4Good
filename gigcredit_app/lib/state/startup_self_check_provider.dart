import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_native_bridge.dart';
import 'app_runtime_policy_provider.dart';
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
  try {
    health = await ref.watch(nativeRuntimeHealthProvider.future);
  } catch (_) {
    health = null;
  }

  final failures = <String>[];

  if (productionRequired) {
    if (!policy.backendConfigured) {
      failures.add('Backend base URL is not configured. Set GIGCREDIT_BACKEND_BASE_URL.');
    }

    if (health == null || health.ready != true) {
      failures.add('Native runtime is unavailable.');
    } else {
      if (health.supportsOcr != true) {
        failures.add('OCR runtime/capability is unavailable (model/dependency missing).');
      }
      if (health.supportsAuthenticity != true) {
        failures.add('Authenticity model path is unavailable (TFLite/model missing).');
      }
      if (health.supportsFaceMatch != true) {
        failures.add('Face-match model path is unavailable (TFLite/model missing).');
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_mode.dart';

class AppRuntimePolicy {
  const AppRuntimePolicy({
    required this.requireProductionReadiness,
    required this.backendConfigured,
    this.enforceBundledAssetChecks = true,
  });

  final bool requireProductionReadiness;
  final bool backendConfigured;
  final bool enforceBundledAssetChecks;
}

final appRuntimePolicyProvider = Provider<AppRuntimePolicy>((ref) {
  return AppRuntimePolicy(
    requireProductionReadiness: AppMode.requireProductionReadiness,
    backendConfigured: AppMode.backendConfigured,
    enforceBundledAssetChecks: true,
  );
});

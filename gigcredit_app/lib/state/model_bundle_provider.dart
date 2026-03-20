import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/model_bundle_service.dart';
import 'native_runtime_provider.dart';

final modelBundleProvider = FutureProvider<ModelBundleResult>((ref) async {
  ref.watch(nativeRuntimeRefreshTickProvider);
  final service = ModelBundleService();
  return service.ensureBundledModelsReady();
});

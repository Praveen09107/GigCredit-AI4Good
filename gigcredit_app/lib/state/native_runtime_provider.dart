import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_native_bridge.dart';

final nativeRuntimeRefreshTickProvider = StateProvider<int>((ref) => 0);

final nativeRuntimeHealthProvider = FutureProvider<NativeRuntimeHealth?>((ref) async {
  ref.watch(nativeRuntimeRefreshTickProvider);
  final bridge = NativeAiBridge();
  try {
    return await bridge.getHealth(forceRefresh: true);
  } on NativeBridgeException {
    return null;
  }
});

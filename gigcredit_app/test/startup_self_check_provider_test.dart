import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/ai_native_bridge.dart';
import 'package:gigcredit_app/state/app_runtime_policy_provider.dart';
import 'package:gigcredit_app/state/native_runtime_provider.dart';
import 'package:gigcredit_app/state/startup_self_check_provider.dart';

void main() {
  NativeRuntimeHealth health({
    bool ready = true,
    bool? ocr = true,
    bool? tflite = true,
    bool? auth = true,
    bool? face = true,
  }) {
    return NativeRuntimeHealth(
      ready: ready,
      engineVersion: 'test-runtime',
      modelsLoaded: true,
      fetchedAt: DateTime(2026, 3, 19, 12, 0, 0),
      ocrRuntimeAvailable: ocr,
      tfliteRuntimeAvailable: tflite,
      authenticityModelAvailable: auth,
      faceModelAvailable: face,
    );
  }

  group('startupSelfCheckProvider', () {
    test('does not block when production mode is disabled', () async {
      final container = ProviderContainer(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: false,
              backendConfigured: false,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupSelfCheckProvider.future);
      expect(result.productionRequired, isFalse);
      expect(result.blocking, isFalse);
      expect(result.failures, isEmpty);
    });

    test('blocks when production mode enabled and backend/native unavailable', () async {
      final container = ProviderContainer(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: true,
              backendConfigured: false,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupSelfCheckProvider.future);
      expect(result.productionRequired, isTrue);
      expect(result.blocking, isTrue);
      expect(
        result.failures,
        contains('Backend base URL is not configured. Set GIGCREDIT_BACKEND_BASE_URL.'),
      );
      expect(result.failures, contains('Native runtime is unavailable.'));
    });

    test('does not block when production mode enabled and all capabilities available', () async {
      final container = ProviderContainer(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: true,
              backendConfigured: true,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith((ref) async => health()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupSelfCheckProvider.future);
      expect(result.productionRequired, isTrue);
      expect(result.blocking, isFalse);
      expect(result.failures, isEmpty);
    });

    test('blocks when production mode enabled and capability checks fail', () async {
      final container = ProviderContainer(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: true,
              backendConfigured: true,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith(
            (ref) async => health(ocr: false, auth: false, face: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupSelfCheckProvider.future);
      expect(result.blocking, isTrue);
      expect(
        result.failures,
        contains('OCR runtime/capability is unavailable (model/dependency missing).'),
      );
      expect(
        result.failures,
        contains('Authenticity model path is unavailable (TFLite/model missing).'),
      );
      expect(
        result.failures,
        contains('Face-match model path is unavailable (TFLite/model missing).'),
      );
    });
  });
}

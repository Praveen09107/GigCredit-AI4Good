import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gigcredit_app/ai/ai_native_bridge.dart';
import 'package:gigcredit_app/state/app_runtime_policy_provider.dart';
import 'package:gigcredit_app/state/native_runtime_provider.dart';
import 'package:gigcredit_app/ui/startup_self_check_gate.dart';

void main() {
  NativeRuntimeHealth healthyRuntime() {
    return NativeRuntimeHealth(
      ready: true,
      engineVersion: 'test-runtime',
      modelsLoaded: true,
      fetchedAt: DateTime(2026, 3, 19, 12, 0, 0),
      ocrRuntimeAvailable: true,
      tfliteRuntimeAvailable: true,
      authenticityModelAvailable: true,
      faceModelAvailable: true,
    );
  }

  testWidgets('shows child when startup is not blocked', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: false,
              backendConfigured: false,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith((ref) async => healthyRuntime()),
        ],
        child: const MaterialApp(
          home: StartupSelfCheckGate(child: Text('APP_OK')),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('APP_OK'), findsOneWidget);
  });

  testWidgets('shows blocking screen when startup checks fail in production mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: true,
              backendConfigured: false,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: StartupSelfCheckGate(child: Text('APP_OK')),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Production Readiness Check'), findsOneWidget);
    expect(find.textContaining('Backend base URL is not configured'), findsOneWidget);
    expect(find.textContaining('Native runtime is unavailable'), findsOneWidget);
    expect(find.text('APP_OK'), findsNothing);
  });

  testWidgets('shows fallback error state when provider errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appRuntimePolicyProvider.overrideWithValue(
            const AppRuntimePolicy(
              requireProductionReadiness: true,
              backendConfigured: true,
            ),
          ),
          nativeRuntimeHealthProvider.overrideWith((ref) => Future<NativeRuntimeHealth?>.error(Exception('boom'))),
        ],
        child: const MaterialApp(
          home: StartupSelfCheckGate(child: Text('APP_OK')),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Production Readiness Check'), findsOneWidget);
    expect(find.textContaining('Native runtime is unavailable'), findsOneWidget);
  });
}

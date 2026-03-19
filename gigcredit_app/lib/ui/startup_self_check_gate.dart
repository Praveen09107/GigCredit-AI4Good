import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/native_runtime_provider.dart';
import '../state/app_runtime_policy_provider.dart';
import '../state/startup_self_check_provider.dart';

class StartupSelfCheckGate extends ConsumerWidget {
  const StartupSelfCheckGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appRuntimePolicyProvider);
    final check = ref.watch(startupSelfCheckProvider);

    return check.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Startup self-check failed unexpectedly.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    final notifier = ref.read(nativeRuntimeRefreshTickProvider.notifier);
                    notifier.state = notifier.state + 1;
                    ref.invalidate(startupSelfCheckProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (result) {
        if (!result.blocking) {
          return child;
        }

        final checked = result.checkedAt;
        final checkedText =
            '${checked.hour.toString().padLeft(2, '0')}:${checked.minute.toString().padLeft(2, '0')}:${checked.second.toString().padLeft(2, '0')}';

        return Scaffold(
          appBar: AppBar(title: const Text('Production Readiness Check')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Production mode is enabled. Startup is blocked until all required capabilities are available.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Last checked: $checkedText'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blocking issues', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...result.failures.map((failure) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('• $failure'),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  final notifier = ref.read(nativeRuntimeRefreshTickProvider.notifier);
                  notifier.state = notifier.state + 1;
                  ref.invalidate(startupSelfCheckProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Re-run checks'),
              ),
            ],
          ),
        );
      },
    );
  }
}

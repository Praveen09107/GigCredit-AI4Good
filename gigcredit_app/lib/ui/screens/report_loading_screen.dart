import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../state/report_provider.dart';
import '../../state/verified_profile_provider.dart';
import '../widgets/app_loading_view.dart';

class ReportLoadingScreen extends ConsumerStatefulWidget {
  const ReportLoadingScreen({super.key});

  @override
  ConsumerState<ReportLoadingScreen> createState() => _ReportLoadingScreenState();
}

class _ReportLoadingScreenState extends ConsumerState<ReportLoadingScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile = ref.read(verifiedProfileProvider);
      await ref.read(reportProvider.notifier).generateFromProfile(profile);
      if (!mounted) return;
      final reportState = ref.read(reportProvider);
      if (reportState.report != null) {
        Navigator.of(context).pushReplacementNamed(AppRouter.report);
        return;
      }
      final message = reportState.error ?? 'Failed to generate report.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(reportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Generating Report')),
      body: AppLoadingView(
        message: reportState.isLoading
            ? 'Preparing multilingual credit report...'
            : 'Finalizing report...',
      ),
    );
  }
}

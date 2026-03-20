import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_router.dart';
import '../../models/enums/report_language.dart';
import '../../state/report_provider.dart';
import '../widgets/app_error_view.dart';

class FinalReportScreen extends ConsumerWidget {
  const FinalReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(reportProvider);
    final report = reportState.report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Credit Report'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppRouter.home, (route) => false),
            child: const Text('Home'),
          ),
        ],
      ),
      body: report == null
          ? AppErrorView(
              message: reportState.error ?? 'No report available.',
              actionLabel: 'Retry',
              onAction: () => Navigator.of(context).pushReplacementNamed(AppRouter.reportLoading),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const Text('Report Language', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReportLanguage.values.map((lang) {
                    return ChoiceChip(
                      label: Text(lang.label),
                      selected: reportState.selectedLanguage == lang,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(reportProvider.notifier).setLanguage(lang);
                          Navigator.of(context).pushReplacementNamed(AppRouter.reportLoading);
                        }
                      },
                    );
                  }).toList(),
                ),
                const Divider(height: 26),
                Text(report.profileName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Credit Score: ${report.score}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Risk Band: ${report.riskBand}'),
                        const SizedBox(height: 8),
                        Text(report.summary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Positive Drivers', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...report.positives.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      leading: const Icon(Icons.check_circle_outline),
                    )),
                const SizedBox(height: 10),
                const Text('Concerns', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...report.concerns.map((item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item),
                      leading: const Icon(Icons.error_outline),
                    )),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await ref.read(reportProvider.notifier).exportPdf();
                    final bytes = ref.read(reportProvider).lastPdfBytes;
                    final message = bytes == null
                        ? 'PDF export failed.'
                        : 'PDF bytes prepared (${bytes.length} bytes).';
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF (Hook)'),
                ),
              ],
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_native_bridge.dart';
import '../models/enums/work_type.dart';
import '../services/mock_api_client.dart';
import '../state/native_runtime_provider.dart';
import '../state/scoring_provider.dart';
import '../state/verified_profile_provider.dart';

class ScoringWorkbenchScreen extends ConsumerStatefulWidget {
  const ScoringWorkbenchScreen({super.key});

  @override
  ConsumerState<ScoringWorkbenchScreen> createState() => _ScoringWorkbenchScreenState();
}

class _ScoringWorkbenchScreenState extends ConsumerState<ScoringWorkbenchScreen> {
  final _nameController = TextEditingController(text: 'Ravi Kumar');
  final _phoneController = TextEditingController(text: '9876543210');
  final _incomeController = TextEditingController(text: '28000');
  final _mockApi = const MockApiClient();

  WorkType _workType = WorkType.platformWorker;
  bool _gatePassed = true;
  String? _reportText;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(verifiedProfileProvider);
    final nativeHealth = ref.watch(nativeRuntimeHealthProvider);
    final request = ScoringRequest(
      features: profile.featureVector,
      minimumGatePassed: profile.minimumGatePassed,
      workTypeIndex: profile.workType.metaIndex,
    );
    final scoreAsync = ref.watch(scoringOutcomeProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: const Text('GigCredit Scoring Workbench'),
        actions: [
          TextButton(
            onPressed: () => ref.read(verifiedProfileProvider.notifier).resetAll(),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNativeRuntimeCard(nativeHealth),
          const SizedBox(height: 16),
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildActionsCard(scoreAsync),
          const SizedBox(height: 16),
          _buildScoreCard(scoreAsync),
          if (_reportText != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_reportText!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNativeRuntimeCard(AsyncValue<NativeRuntimeHealth?> nativeHealth) {
    void refreshRuntimeStatus() {
      final notifier = ref.read(nativeRuntimeRefreshTickProvider.notifier);
      notifier.state = notifier.state + 1;
    }

    return nativeHealth.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Checking native AI runtime...'),
        ),
      ),
      error: (error, _) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Native runtime unavailable. Using fallback engines for OCR/authenticity/face matching.',
          ),
        ),
      ),
      data: (health) {
        if (health == null || health.ready != true) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Native runtime unavailable. Using fallback engines for OCR/authenticity/face matching.',
              ),
            ),
          );
        }

        final fallbacks = <String>[];
        if (health.supportsOcr != true) {
          fallbacks.add('OCR');
        }
        if (health.supportsAuthenticity != true) {
          fallbacks.add('authenticity');
        }
        if (health.supportsFaceMatch != true) {
          fallbacks.add('face match');
        }

        final message = fallbacks.isEmpty
            ? 'Native runtime active (${health.engineVersion}). All model-backed paths available.'
            : 'Native runtime active (${health.engineVersion}), but using fallback for: ${fallbacks.join(', ')}.';
        final checked = health.fetchedAt;
        final checkedText =
            '${checked.hour.toString().padLeft(2, '0')}:${checked.minute.toString().padLeft(2, '0')}:${checked.second.toString().padLeft(2, '0')}';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Runtime Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: refreshRuntimeStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 6),
                Text(
                  'Last checked: $checkedText',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Applicant Profile', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone number')),
            const SizedBox(height: 10),
            TextField(
              controller: _incomeController,
              decoration: const InputDecoration(labelText: 'Monthly income (INR)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<WorkType>(
              initialValue: _workType,
              decoration: const InputDecoration(labelText: 'Work type'),
              items: WorkType.values
                  .map((type) => DropdownMenuItem<WorkType>(value: type, child: Text(type.label)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _workType = value);
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _gatePassed,
              title: const Text('Minimum scoring gate passed'),
              subtitle: const Text('Step 1 + Step 2 verified + Step 3 with >= 30 transactions'),
              onChanged: (value) => setState(() => _gatePassed = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(AsyncValue<dynamic> scoreAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: _applyProfile,
              icon: const Icon(Icons.person),
              label: const Text('Apply Profile'),
            ),
            ElevatedButton.icon(
              onPressed: _regenerateFeatures,
              icon: const Icon(Icons.auto_graph),
              label: const Text('Generate Features'),
            ),
            ElevatedButton.icon(
              onPressed: scoreAsync is AsyncLoading ? null : _generateMockReport,
              icon: const Icon(Icons.description),
              label: const Text('Generate Mock Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(AsyncValue<dynamic> scoreAsync) {
    return scoreAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Scoring error: $error'),
        ),
      ),
      data: (outcome) {
        final pillarTiles = outcome.pillarScores.entries
            .map(
              (entry) => ListTile(
                dense: true,
                title: Text(entry.key.toUpperCase()),
                trailing: Text(entry.value.toStringAsFixed(3)),
              ),
            )
            .toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Score', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Eligible: ${outcome.eligible}'),
                Text('Final score: ${outcome.finalScore}'),
                Text('Probability: ${outcome.probability.toStringAsFixed(4)}'),
                Text('Risk band: ${outcome.riskBand}'),
                const Divider(height: 24),
                ...pillarTiles,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyProfile() async {
    final income = double.tryParse(_incomeController.text.trim()) ?? 0;
    await ref.read(verifiedProfileProvider.notifier).updateBasicProfile(
          fullName: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          monthlyIncome: income,
          workType: _workType,
        );
    await ref.read(verifiedProfileProvider.notifier).setMinimumGate(_gatePassed);
  }

  Future<void> _regenerateFeatures() async {
    await _applyProfile();
    await ref.read(verifiedProfileProvider.notifier).regenerateFeatures();
  }

  Future<void> _generateMockReport() async {
    final profile = ref.read(verifiedProfileProvider);
    final request = ScoringRequest(
      features: profile.featureVector,
      minimumGatePassed: profile.minimumGatePassed,
      workTypeIndex: profile.workType.metaIndex,
    );
    final outcome = await ref.read(scoringOutcomeProvider(request).future);
    final response = await _mockApi.generateReport({'score': outcome.finalScore});
    final explanation = response.data?['explanation']?.toString() ?? 'No explanation';
    final suggestions = (response.data?['suggestions'] as List<dynamic>? ?? const [])
        .map((item) => '- ${item.toString()}')
        .join('\n');

    setState(() {
      _reportText = '$explanation\n\n$suggestions';
    });
  }
}

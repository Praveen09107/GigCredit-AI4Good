import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline/pending_verification_queue.dart';
import '../core/offline/reconciliation_service.dart';
import '../core/session/secure_storage.dart';
import '../services/backend_client.dart';

final pendingVerificationQueueProvider = Provider<PendingVerificationQueue>(
  (ref) => PendingVerificationQueue(storage: const SecureStorage()),
);

final offlineSyncServiceProvider = Provider<OfflineSyncService>(
  (ref) => OfflineSyncService(queue: ref.read(pendingVerificationQueueProvider)),
);

class OfflineSyncService {
  OfflineSyncService({required PendingVerificationQueue queue}) : _queue = queue;

  final PendingVerificationQueue _queue;

  Future<void> queueVerification({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final task = PendingVerificationTask(
      id: 'task_${DateTime.now().microsecondsSinceEpoch}',
      path: path,
      body: body,
      createdAt: DateTime.now(),
    );
    await _queue.enqueue(task);
  }

  Future<int> pendingCount() async {
    final tasks = await _queue.getAll();
    return tasks.length;
  }

  Future<ReconciliationResult> retryWhenOnline(BackendClient client) async {
    final service = ReconciliationService(client: client, queue: _queue);
    return service.retryDueTasks();
  }

  Future<void> clearQueue() async {
    await _queue.clear();
  }
}

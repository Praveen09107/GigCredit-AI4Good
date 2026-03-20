import '../../services/backend_client.dart';
import 'pending_verification_queue.dart';

class ReconciliationResult {
  const ReconciliationResult({
    required this.total,
    required this.retried,
    required this.succeeded,
    required this.failed,
  });

  final int total;
  final int retried;
  final int succeeded;
  final int failed;
}

class ReconciliationService {
  ReconciliationService({
    required BackendClient client,
    required PendingVerificationQueue queue,
  })  : _client = client,
        _queue = queue;

  final BackendClient _client;
  final PendingVerificationQueue _queue;

  Future<ReconciliationResult> retryDueTasks({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final tasks = await _queue.getAll();

    var retried = 0;
    var succeeded = 0;
    var failed = 0;

    final remaining = <PendingVerificationTask>[];

    for (final task in tasks) {
      final due = task.nextRetryAt == null || !task.nextRetryAt!.isAfter(current);
      if (!due) {
        remaining.add(task);
        continue;
      }

      retried += 1;
      try {
        final response = await _client.postJson(task.path, task.body);
        final ok = response.status.toUpperCase() == 'SUCCESS' || response.status.toUpperCase() == 'OK';

        if (ok) {
          succeeded += 1;
        } else {
          failed += 1;
          remaining.add(_reschedule(task, current));
        }
      } catch (_) {
        failed += 1;
        remaining.add(_reschedule(task, current));
      }
    }

    await _queue.replaceAll(remaining);

    return ReconciliationResult(
      total: tasks.length,
      retried: retried,
      succeeded: succeeded,
      failed: failed,
    );
  }

  PendingVerificationTask _reschedule(PendingVerificationTask task, DateTime now) {
    final nextAttempts = task.attempts + 1;
    final waitMinutes = _backoffMinutes(nextAttempts);
    return task.copyWith(
      attempts: nextAttempts,
      nextRetryAt: now.add(Duration(minutes: waitMinutes)),
    );
  }

  int _backoffMinutes(int attempts) {
    final raw = 1 << (attempts.clamp(1, 6) - 1);
    return raw > 60 ? 60 : raw;
  }
}

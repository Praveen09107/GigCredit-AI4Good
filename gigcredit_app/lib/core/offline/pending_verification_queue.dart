import '../../core/session/secure_storage.dart';

class PendingVerificationTask {
  const PendingVerificationTask({
    required this.id,
    required this.path,
    required this.body,
    required this.createdAt,
    this.attempts = 0,
    this.nextRetryAt,
  });

  final String id;
  final String path;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextRetryAt;

  PendingVerificationTask copyWith({
    int? attempts,
    DateTime? nextRetryAt,
  }) {
    return PendingVerificationTask(
      id: id,
      path: path,
      body: body,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'path': path,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  static PendingVerificationTask fromJson(Map<String, dynamic> json) {
    return PendingVerificationTask(
      id: '${json['id'] ?? ''}',
      path: '${json['path'] ?? ''}',
      body: (json['body'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: json['nextRetryAt'] == null ? null : DateTime.tryParse('${json['nextRetryAt']}'),
    );
  }
}

class PendingVerificationQueue {
  PendingVerificationQueue({required SecureStorage storage}) : _storage = storage;

  static const String _storageKey = 'offline_pending_verification_queue_v1';

  final SecureStorage _storage;

  Future<List<PendingVerificationTask>> getAll() async {
    final json = await _storage.readJson(_storageKey);
    final rawList = (json?['tasks'] as List?) ?? const <dynamic>[];

    return rawList
        .whereType<Map>()
        .map((e) => PendingVerificationTask.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<void> enqueue(PendingVerificationTask task) async {
    final tasks = await getAll();
    final updated = <PendingVerificationTask>[...tasks, task];
    await _save(updated);
  }

  Future<void> replaceAll(List<PendingVerificationTask> tasks) async {
    await _save(tasks);
  }

  Future<void> clear() async {
    await _storage.deleteKey(_storageKey);
  }

  Future<void> _save(List<PendingVerificationTask> tasks) async {
    await _storage.writeJson(
      _storageKey,
      <String, dynamic>{
        'tasks': tasks.map((t) => t.toJson()).toList(growable: false),
      },
    );
  }
}

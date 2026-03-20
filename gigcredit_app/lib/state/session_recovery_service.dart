import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/secure_storage.dart';
import '../models/verified_profile.dart';
import 'verified_profile_provider.dart';

final sessionRecoveryServiceProvider = Provider<SessionRecoveryService>(
  (ref) => SessionRecoveryService(storage: const SecureStorage()),
);

class SessionRecoveryService {
  SessionRecoveryService({required SecureStorage storage}) : _storage = storage;

  static const String _key = 'verified_profile_session_v1';
  final SecureStorage _storage;

  Future<void> persistProfile(
    VerifiedProfile profile, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final payload = <String, dynamic>{
      'expiresAt': DateTime.now().add(ttl).toIso8601String(),
      'profile': _toJson(profile),
    };
    await _storage.writeJson(_key, payload);
  }

  Future<bool> restore(VerifiedProfileNotifier notifier) async {
    final payload = await _storage.readJson(_key);
    if (payload == null) return false;

    final expiresAt = DateTime.tryParse('${payload['expiresAt'] ?? ''}');
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await clear();
      return false;
    }

    final profileJson = (payload['profile'] as Map?)?.cast<String, dynamic>();
    if (profileJson == null) {
      await clear();
      return false;
    }

    notifier.restoreState(_fromJson(profileJson));
    return true;
  }

  Future<void> clear() async {
    await _storage.deleteKey(_key);
  }

  Map<String, dynamic> _toJson(VerifiedProfile p) {
    return p.toJson();
  }

  VerifiedProfile _fromJson(Map<String, dynamic> j) {
    return VerifiedProfile.fromJson(j);
  }
}

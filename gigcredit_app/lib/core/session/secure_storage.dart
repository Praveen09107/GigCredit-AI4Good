import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/verified_profile.dart';

class SecureStorage {
  const SecureStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _profileKey = 'gigcredit_verified_profile';
  final FlutterSecureStorage _storage;

  Future<void> saveProfile(VerifiedProfile profile) async {
    final encoded = jsonEncode(profile.toJson());
    await _storage.write(key: _profileKey, value: encoded);
  }

  Future<VerifiedProfile?> readProfile() async {
    String? raw;
    try {
      raw = await _storage.read(key: _profileKey);
    } catch (_) {
      // If decrypt fails (e.g. WRONG_FINAL_BLOCK_LENGTH), the stored value is corrupted.
      // Purge the key so login/OTP flow can proceed.
      await _storage.delete(key: _profileKey);
      return null;
    }

    if (raw == null || raw.isEmpty) return null;

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      return VerifiedProfile.fromJson(parsed);
    } catch (_) {
      // Corrupted JSON payload; delete and fall back to empty state.
      await _storage.delete(key: _profileKey);
      return null;
    }
  }

  Future<void> clearProfile() {
    return _storage.delete(key: _profileKey);
  }

  // ── Generic JSON helpers used by queue / recovery services ──
  Future<Map<String, dynamic>?> readJson(String key) async {
    String? raw;
    try {
      raw = await _storage.read(key: key);
    } catch (_) {
      // Decrypt can fail if app/keystore changed between runs.
      // Delete the corrupted key and return null to allow recovery.
      await _storage.delete(key: key);
      return null;
    }

    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await _storage.write(key: key, value: jsonEncode(value));
  }

  Future<void> deleteKey(String key) {
    return _storage.delete(key: key);
  }

  Future<void> writeString(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  Future<String?> readString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // Best-effort recovery: delete corrupted value then treat as missing.
      await _storage.delete(key: key);
      return null;
    }
  }
}


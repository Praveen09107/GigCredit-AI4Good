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
    final raw = await _storage.read(key: _profileKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    return VerifiedProfile.fromJson(parsed);
  }

  Future<void> clearProfile() {
    return _storage.delete(key: _profileKey);
  }
}


import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/session/secure_storage.dart';

class OtpVerificationResult {
  const OtpVerificationResult({required this.isNewUser, required this.user});

  final bool isNewUser;
  final User? user;
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    SecureStorage? storage,
  })  : _authOverride = firebaseAuth,
        _firestoreOverride = firestore,
        _storage = storage ?? const SecureStorage();

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final SecureStorage _storage;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;

  // Debug bypass is opt-in only and disabled by default.
  static const bool _enableDebugOtpBypass = bool.fromEnvironment('GIGCREDIT_DEBUG_OTP_BYPASS', defaultValue: false);
  static const String _debugBypassPhone = String.fromEnvironment('GIGCREDIT_DEBUG_OTP_PHONE', defaultValue: '');
  static const String _debugBypassVerificationId = 'mock_verification_id';
  static const String _debugBypassOtp = '000000';
  static const String _lastSignedInPhoneKey = 'auth.last_signed_in_phone';
  static const String _registeredPhonesKey = 'auth.registered_phones';
  // Keep OTP auth independent from Firestore setup. Can be enabled explicitly when backend is ready.
  static const bool _enableFirestoreProfileBootstrap = bool.fromEnvironment(
    'GIGCREDIT_ENABLE_FIRESTORE_PROFILE_BOOTSTRAP',
    defaultValue: false,
  );

  User? get currentUser => _auth.currentUser;

  String normalizeIndianPhone(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    if (phoneNumber.startsWith('+')) {
      return phoneNumber;
    }
    return '+91$digits';
  }

  Future<bool> hasAccountForPhone(String phoneNumber) async {
    if (!_enableFirestoreProfileBootstrap) {
      return false;
    }

    final normalized = normalizeIndianPhone(phoneNumber);
    final snapshot = await _firestore
        .collection('user_profiles')
        .where('phoneNumber', isEqualTo: normalized)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Returns null when account presence cannot be determined (e.g., Firestore unavailable).
  Future<bool?> hasAccountForPhoneBestEffort(String phoneNumber) async {
    try {
      return await hasAccountForPhone(phoneNumber);
    } catch (_) {
      return null;
    }
  }

  Future<void> rememberSignedInPhone(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) return;
    final normalized = normalizeIndianPhone(phoneNumber);
    await _storage.writeString(_lastSignedInPhoneKey, normalized);
  }

  Future<bool> isKnownPhoneOnDevice(String phoneNumber) async {
    final normalized = normalizeIndianPhone(phoneNumber);
    try {
      final remembered = await _storage.readString(_lastSignedInPhoneKey);
      return remembered == normalized;
    } catch (_) {
      // If secure storage decryption fails, treat device as unknown.
      return false;
    }
  }

  Future<Set<String>> _getRegisteredPhones() async {
    String? raw;
    try {
      raw = await _storage.readString(_registeredPhonesKey);
    } catch (_) {
      // If secure storage decryption fails, treat as empty local registry.
      return <String>{};
    }
    if (raw == null || raw.trim().isEmpty) {
      return <String>{};
    }
    final values = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    return values;
  }

  Future<void> _saveRegisteredPhones(Set<String> phones) async {
    final csv = phones.join(',');
    await _storage.writeString(_registeredPhonesKey, csv);
  }

  Future<bool> isPhoneRegisteredLocally(String phoneNumber) async {
    final normalized = normalizeIndianPhone(phoneNumber);
    final phones = await _getRegisteredPhones();
    return phones.contains(normalized);
  }

  Future<void> markPhoneRegistered(String phoneNumber) async {
    final normalized = normalizeIndianPhone(phoneNumber);
    final phones = await _getRegisteredPhones();
    phones.add(normalized);
    await _saveRegisteredPhones(phones);
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? forceResendingToken) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    required void Function(String message) onError,
    int? forceResendingToken,
  }) async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      onError(
        'Phone OTP is not supported on desktop runtime. Run this screen on Android/iOS (or Web with Firebase reCAPTCHA enabled).',
      );
      return;
    }

    if (kDebugMode && _enableDebugOtpBypass && phoneNumber == _debugBypassPhone) {
      Future.delayed(const Duration(milliseconds: 500), () {
        onCodeSent(_debugBypassVerificationId, null);
      });
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phoneNumber',
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          await rememberSignedInPhone(userCredential.user?.phoneNumber);
          if (_enableFirestoreProfileBootstrap) {
            await _createUserProfileIfMissingSafe(userCredential.user);
          }
          onAutoVerified();
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_mapFirebaseError(e));
        },
        codeSent: (String verificationId, int? token) {
          onCodeSent(verificationId, token);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          onCodeAutoRetrievalTimeout(verificationId);
        },
      );
    } on FirebaseAuthException catch (e) {
      onError(_mapFirebaseError(e));
    } on UnimplementedError {
      onError(
        'OTP flow is not implemented for this runtime. Use Android/iOS device for phone OTP.',
      );
    } on UnsupportedError {
      onError(
        'OTP is unavailable on this runtime. Use Android/iOS device for Firebase phone verification.',
      );
    } catch (e) {
      onError('Unable to send OTP. ${e.toString()}');
    }
  }

  Future<OtpVerificationResult> verifyOtp({
    required String verificationId,
    required String smsCode,
    bool createProfileIfMissing = true,
  }) async {
    if (kDebugMode && _enableDebugOtpBypass && verificationId == _debugBypassVerificationId && smsCode == _debugBypassOtp) {
      return OtpVerificationResult(isNewUser: false, user: _auth.currentUser);
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
    await rememberSignedInPhone(userCredential.user?.phoneNumber);
    if (createProfileIfMissing && _enableFirestoreProfileBootstrap) {
      await _createUserProfileIfMissingSafe(userCredential.user);
    }
    return OtpVerificationResult(isNewUser: isNewUser, user: userCredential.user);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> rollbackNewPhoneUser(User? user) async {
    try {
      await user?.delete();
    } catch (_) {
      // If deletion fails, keep user signed out so app state remains consistent.
    } finally {
      await signOut();
    }
  }

  String mapFirebaseErrorForUi(FirebaseAuthException e) => _mapFirebaseError(e);

  String mapAnyErrorForUi(Object e) {
    if (e is FirebaseAuthException) {
      return _mapFirebaseError(e);
    }

    final msg = e.toString().toUpperCase();
    if (msg.contains('RECAPTCHA') || msg.contains('SITEKEY')) {
      return 'Phone auth requires reCAPTCHA configuration for this Firebase project. Configure reCAPTCHA Enterprise/site key in Firebase Authentication settings.';
    }
    if (msg.contains('NETWORK')) {
      return 'Network error during OTP verification. Check internet and retry.';
    }
    if (msg.contains('TOO_MANY_REQUESTS')) {
      return 'Too many OTP attempts. Please wait and retry.';
    }
    return 'OTP verification failed. ${e.toString()}';
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    final message = (e.message ?? '').toUpperCase();
    if (message.contains('BILLING_NOT_ENABLED')) {
      return 'Firebase phone OTP is blocked: billing is not enabled for this project. Enable billing on Google Cloud and retry.';
    }
    if (message.contains('RECAPTCHA') || message.contains('SITEKEY')) {
      return 'Phone auth reCAPTCHA/site-key setup is missing for this Firebase project. Configure it in Firebase Authentication and retry.';
    }

    switch (e.code) {
      case 'operation-not-allowed':
        return 'Phone OTP is not enabled in Firebase Authentication settings. Enable Phone provider and retry.';
      case 'app-not-authorized':
        return 'This app is not authorized for Firebase phone auth. Check package name/SHA keys in Firebase.';
      case 'invalid-app-credential':
        return 'Invalid app credential for phone auth. Verify Play Integrity/SafetyNet or iOS APNs setup.';
      case 'invalid-credential':
        return 'Invalid OTP credential/session. Request a new OTP and retry.';
      case 'invalid-verification-id':
        return 'OTP session is invalid. Request a new OTP and retry.';
      case 'missing-verification-code':
        return 'Please enter the OTP code.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Retry on stable network, or verify Firebase web auth domain settings.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for this Firebase project. Try later or increase quota/billing.';
      case 'invalid-phone-number':
        return 'Invalid mobile number format.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please retry.';
      case 'session-expired':
        return 'OTP expired. Request a new OTP.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> _createUserProfileIfMissing(User? user) async {
    if (user == null) {
      return;
    }

    final docRef = _firestore.collection('user_profiles').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      return;
    }

    await docRef.set(<String, dynamic>{
      'uid': user.uid,
      'phoneNumber': user.phoneNumber,
      'displayName': user.displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'kycStatus': 'new',
      'source': 'phone_otp',
    });
  }

  Future<void> _createUserProfileIfMissingSafe(User? user) async {
    try {
      await _createUserProfileIfMissing(user);
    } catch (_) {
      // Auth success should not be blocked by optional profile bootstrap failures.
    }
  }
}

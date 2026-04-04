import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists app-lock preference, optional biometric shortcut, and a salted PIN hash.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _kLockEnabled = 'app_lock_enabled';
  static const _kBiometricEnabled = 'app_lock_biometric_enabled';
  static const _kPinSalt = 'app_lock_pin_salt';
  static const _kPinHash = 'app_lock_pin_hash';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _lockEnabled = false;
  bool _biometricEnabled = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isLockEnabled => _lockEnabled;
  bool get isBiometricEnabled => _biometricEnabled;

  Future<void> load() async {
    if (kIsWeb) {
      _lockEnabled = false;
      _biometricEnabled = false;
      _loaded = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _lockEnabled = prefs.getBool(_kLockEnabled) ?? false;
    _biometricEnabled = prefs.getBool(_kBiometricEnabled) ?? false;
    _loaded = true;
  }

  Future<bool> hasPinConfigured() async {
    if (kIsWeb) return false;
    final hash = await _secure.read(key: _kPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Exactly 4 digits.
  static bool isValidPinFormat(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> setPin(String pin) async {
    if (kIsWeb || !isValidPinFormat(pin)) return;
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltB64 = base64UrlEncode(salt);
    final hash = _hash(pin, saltB64);
    await _secure.write(key: _kPinSalt, value: saltB64);
    await _secure.write(key: _kPinHash, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    if (kIsWeb) return false;
    final salt = await _secure.read(key: _kPinSalt);
    final stored = await _secure.read(key: _kPinHash);
    if (salt == null || stored == null) return false;
    return _hash(pin, salt) == stored;
  }

  Future<void> setLockEnabled(bool enabled) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLockEnabled, enabled);
    _lockEnabled = enabled;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabled, enabled);
    _biometricEnabled = enabled;
  }

  Future<void> clearLockAndPin() async {
    if (kIsWeb) return;
    await _secure.delete(key: _kPinSalt);
    await _secure.delete(key: _kPinHash);
    await setLockEnabled(false);
    await setBiometricEnabled(false);
  }

  Future<bool> deviceCanCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock Expense Tracker',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const _phoneKey = 'bio_phone';
  static const _passwordKey = 'bio_password';
  static const _enabledKey = 'bio_enabled';

  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    return (await _storage.read(key: _enabledKey)) == 'true';
  }

  Future<bool> hasSavedCredentials() async {
    final phone = await _storage.read(key: _phoneKey);
    final pw = await _storage.read(key: _passwordKey);
    return phone != null && pw != null && (await isEnabled());
  }

  Future<void> enable({required String phone, required String password}) async {
    await _storage.write(key: _phoneKey, value: phone);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<void> disable() async {
    await _storage.delete(key: _phoneKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _enabledKey);
  }

  Future<({String phone, String password})?> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true, persistAcrossBackgrounding: true,
      );
      if (!ok) return null;
      final phone = await _storage.read(key: _phoneKey);
      final password = await _storage.read(key: _passwordKey);
      if (phone == null || password == null) return null;
      return (phone: phone, password: password);
    } on PlatformException {
      return null;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((_) => BiometricService());

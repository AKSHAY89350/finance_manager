import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing device biometric security (Fingerprint / Face ID / Screen Lock).
/// Stores user preference in local SharedPreferences (100% offline).
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _keyBiometricEnabled = 'pref_biometric_enabled';

  /// Check whether the device supports biometric hardware or device credential
  static Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Check whether biometric app lock is enabled by the user in Settings
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Toggle biometric app lock setting
  static Future<bool> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  /// Prompt user for Fingerprint / Face ID / Device PIN
  static Future<bool> authenticate({
    String reason = 'Unlock Finance Manager to access your records',
  }) async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false; // Fail closed: require device credential / biometrics

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // Allows device PIN/pattern fallback
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}

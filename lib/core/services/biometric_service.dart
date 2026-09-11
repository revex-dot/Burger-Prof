import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'prefs_service.dart';

class BiometricService {
  BiometricService([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow device PIN fallback
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

final biometricServiceProvider = Provider((_) => BiometricService());

/// Whether the user enabled the biometric app lock in Settings.
class BiometricLockController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(PrefKeys.biometricLock) ??
      false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.biometricLock, enabled);
  }
}

final biometricLockEnabledProvider =
    NotifierProvider<BiometricLockController, bool>(
  BiometricLockController.new,
);

/// `true` once the user has passed the lock screen for this app launch.
final appUnlockedProvider = StateProvider<bool>((_) => false);

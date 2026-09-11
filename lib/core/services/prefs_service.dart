import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Injected at startup (see `main.dart`) so synchronous reads are possible.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in ProviderScope'),
);

class PrefKeys {
  static const themeMode = 'theme_mode';
  static const locale = 'locale';
  static const biometricLock = 'biometric_lock';
  static const reminders = 'reminder_settings';
  static const pendingUploads = 'pending_uploads';
  static const lastSyncedAt = 'last_synced_at';
}

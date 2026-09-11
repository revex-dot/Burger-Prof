import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prefs_service.dart';

/// Persisted dark-mode toggle (system / light / dark).
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(PrefKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(
          PrefKeys.themeMode,
          mode.name,
        );
  }

  Future<void> toggleDark(bool dark) =>
      set(dark ? ThemeMode.dark : ThemeMode.light);
}

final themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

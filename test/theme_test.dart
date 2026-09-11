import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawsitive_cat/core/services/prefs_service.dart';
import 'package:pawsitive_cat/core/theme/app_theme.dart';
import 'package:pawsitive_cat/core/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('light and dark themes have matching brightness', () {
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
  });

  test('theme mode toggle persists to preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.system);
    await container.read(themeModeProvider.notifier).toggleDark(true);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(prefs.getString(PrefKeys.themeMode), 'dark');

    // A fresh container reads the persisted value.
    final again = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(themeModeProvider), ThemeMode.dark);
  });
}

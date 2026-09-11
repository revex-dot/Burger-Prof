import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/prefs_service.dart';

/// Languages shipped with the app (ARB files in `lib/l10n`).
const supportedLocales = [
  Locale('en'),
  Locale('es'),
  Locale('de'),
  Locale('fr'),
  Locale('pt'),
  Locale('ja'),
];

const localeDisplayNames = {
  'en': 'English',
  'es': 'Español',
  'de': 'Deutsch',
  'fr': 'Français',
  'pt': 'Português',
  'ja': '日本語',
};

/// `null` means "follow the device language".
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final code =
        ref.watch(sharedPreferencesProvider).getString(PrefKeys.locale);
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(PrefKeys.locale);
    } else {
      await prefs.setString(PrefKeys.locale, locale.languageCode);
    }
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/upload_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'l10n/generated/app_localizations.dart';

class PawsitiveCatApp extends ConsumerWidget {
  const PawsitiveCatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // Side effects that must run once a user is signed in.
    ref.listen(currentUidProvider, (prev, uid) {
      if (uid != null && uid != prev) {
        ref
            .read(notificationServiceProvider)
            .registerToken(ref.read(firestoreProvider), uid);
        ref.read(uploadQueueProvider.notifier).flush();
      }
    });

    return MaterialApp.router(
      title: 'Pawsitive Cat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

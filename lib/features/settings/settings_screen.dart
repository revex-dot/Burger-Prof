import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final biometric = ref.watch(biometricLockEnabledProvider);
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final user = ref.watch(appUserProvider).valueOrNull;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(l.appearance),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  title: Text(l.darkMode),
                  value: isDark,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).toggleDark(v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l.themeDark),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l.language),
                  trailing: DropdownButton<String>(
                    value: locale?.languageCode ?? 'system',
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text(l.themeSystem),
                      ),
                      for (final loc in supportedLocales)
                        DropdownMenuItem(
                          value: loc.languageCode,
                          child: Text(localeDisplayNames[loc.languageCode]!),
                        ),
                    ],
                    onChanged: (v) {
                      final controller = ref.read(localeProvider.notifier);
                      controller.set(v == 'system' ? null : Locale(v!));
                      final uid = ref.read(currentUidProvider);
                      if (uid != null && v != 'system') {
                        ref
                            .read(authServiceProvider)
                            .updateProfile(uid, {'locale': v});
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l.security),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l.biometricLock),
              subtitle: Text(l.biometricLockHint),
              value: biometric,
              onChanged: (v) async {
                if (v) {
                  final available =
                      await ref.read(biometricServiceProvider).isAvailable();
                  if (!available) {
                    if (context.mounted) {
                      showSnack(context, l.biometricUnavailable);
                    }
                    return;
                  }
                }
                await ref.read(biometricLockEnabledProvider.notifier).set(v);
                ref.read(appUnlockedProvider.notifier).state = true;
              },
            ),
          ),
          SectionHeader(l.notifications),
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(l.remindersTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.reminders),
            ),
          ),
          SectionHeader(l.syncStatus),
          Card(
            child: ListTile(
              leading: Icon(
                online ? Icons.cloud_done_outlined : Icons.cloud_off,
                color: online ? Colors.green : null,
              ),
              title: Text(online ? l.online : l.offline),
              subtitle: Text(l.dataSyncNote),
              isThreeLine: true,
            ),
          ),
          SectionHeader(l.account),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(user?.displayName ?? ''),
                  subtitle: Text(user?.email ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(l.premiumTitle),
                  subtitle: Text(user?.tier.name.toUpperCase() ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.premium),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l.signOut),
                  onTap: () async {
                    ref.read(appUnlockedProvider.notifier).state = false;
                    await ref.read(authServiceProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

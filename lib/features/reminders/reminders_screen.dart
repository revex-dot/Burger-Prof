import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/common.dart';

/// Daily training reminder + engagement push preferences.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(reminderSettingsProvider);
    final labels = [
      l.weekdayMon,
      l.weekdayTue,
      l.weekdayWed,
      l.weekdayThu,
      l.weekdayFri,
      l.weekdaySat,
      l.weekdaySun,
    ];

    Future<void> update(ReminderSettings s) =>
        ref.read(reminderSettingsProvider.notifier).update(
              s,
              title: l.reminderTitle,
              body: l.reminderBody,
            );

    final time = TimeOfDay(hour: settings.hour, minute: settings.minute);

    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.alarm),
                  title: Text(l.dailyReminder),
                  value: settings.enabled,
                  onChanged: (v) => update(settings.copyWith(enabled: v)),
                ),
                ListTile(
                  enabled: settings.enabled,
                  leading: const Icon(Icons.schedule),
                  title: Text(l.reminderTime),
                  trailing: Text(
                    time.format(context),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (picked == null) return;
                    await update(
                      settings.copyWith(
                          hour: picked.hour, minute: picked.minute),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.repeatOn),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (var d = 1; d <= 7; d++)
                            FilterChip(
                              label: Text(labels[d - 1]),
                              selected: settings.weekdays.contains(d),
                              onSelected: settings.enabled
                                  ? (sel) {
                                      final days = {...settings.weekdays};
                                      sel ? days.add(d) : days.remove(d);
                                      if (days.isEmpty) return;
                                      update(settings.copyWith(weekdays: days));
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.campaign_outlined),
              title: Text(l.engagementNotifications),
              subtitle: Text(l.engagementNotificationsHint),
              value: settings.engagementEnabled,
              onChanged: (v) => update(settings.copyWith(engagementEnabled: v)),
            ),
          ),
        ],
      ),
    );
  }
}

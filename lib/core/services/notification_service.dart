import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'auth_service.dart';
import 'prefs_service.dart';

/// Handles both kinds of push:
///  * Local, scheduled daily training reminders (work fully offline).
///  * Firebase Cloud Messaging for engagement pushes sent by the backend
///    (community replies, impact updates, weekly tips).
class NotificationService {
  NotificationService(this._local, this._messaging);

  final FlutterLocalNotificationsPlugin _local;
  final FirebaseMessaging _messaging;

  static const _channel = AndroidNotificationChannel(
    'training_reminders',
    'Training reminders',
    description: 'Daily reminders to train with your cat',
    importance: Importance.high,
  );

  static const _engagementTopic = 'engagement';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _messaging.requestPermission();
    // Show FCM messages that arrive while the app is in the foreground.
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(_channel.id, _channel.name),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  /// Persist the device FCM token on the user document so Cloud Functions can
  /// target this device.
  Future<void> registerToken(FirebaseFirestore db, String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await db.collection('users').doc(uid).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );
      _messaging.onTokenRefresh.listen((t) {
        db.collection('users').doc(uid).set(
          {
            'fcmTokens': FieldValue.arrayUnion([t]),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> setEngagementEnabled(bool enabled) async {
    try {
      if (enabled) {
        await _messaging.subscribeToTopic(_engagementTopic);
      } else {
        await _messaging.unsubscribeFromTopic(_engagementTopic);
      }
    } catch (e) {
      debugPrint('FCM topic update failed: $e');
    }
  }

  /// (Re)schedules one repeating local notification per selected weekday.
  Future<void> scheduleDailyReminders(
    ReminderSettings settings, {
    required String title,
    required String body,
  }) async {
    await _local.cancelAll();
    if (!settings.enabled) return;

    for (final weekday in settings.weekdays) {
      await _local.zonedSchedule(
        weekday, // stable id per weekday
        title,
        body,
        _nextInstance(weekday, settings.hour, settings.minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  tz.TZDateTime _nextInstance(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(
    FlutterLocalNotificationsPlugin(),
    FirebaseMessaging.instance,
  ),
);

/// Reminder preferences are stored locally (they must work offline) and
/// mirrored to Firestore for cross-device sync.
class ReminderController extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final raw =
        ref.watch(sharedPreferencesProvider).getString(PrefKeys.reminders);
    if (raw == null) return const ReminderSettings();
    try {
      return ReminderSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ReminderSettings();
    }
  }

  Future<void> update(
    ReminderSettings settings, {
    required String title,
    required String body,
  }) async {
    state = settings;
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.reminders, jsonEncode(settings.toJson()));
    final notifications = ref.read(notificationServiceProvider);
    await notifications.scheduleDailyReminders(
      settings,
      title: title,
      body: body,
    );
    await notifications.setEngagementEnabled(settings.engagementEnabled);
    final uid = ref.read(currentUidProvider);
    if (uid != null) {
      await ref.read(firestoreProvider).collection('users').doc(uid).set(
        {'reminders': settings.toJson()},
        SetOptions(merge: true),
      );
    }
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderController, ReminderSettings>(
  ReminderController.new,
);

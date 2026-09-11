import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/prefs_service.dart';
import 'firebase_options.dart';

/// Publishable key only – the secret key lives in Cloud Functions config.
/// Override at build time: `--dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_…`
const _stripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: 'pk_test_REPLACE_ME',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline mode: Firestore keeps an unlimited local cache and queues writes
  // while the device is disconnected, then syncs across devices when online.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  Stripe.publishableKey = _stripePublishableKey;
  Stripe.merchantIdentifier = 'merchant.com.pawsitivecat';

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  try {
    await container.read(notificationServiceProvider).init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PawsitiveCatApp(),
    ),
  );
}

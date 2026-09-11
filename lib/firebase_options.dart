// Template Firebase configuration.
//
// Replace this file by running:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-gcp-project-id>
//
// The placeholders below let the project compile and run the widget tests
// without a real Firebase project. The app itself needs real values.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'pawsitive-cat',
    authDomain: 'pawsitive-cat.firebaseapp.com',
    storageBucket: 'pawsitive-cat.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'pawsitive-cat',
    storageBucket: 'pawsitive-cat.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'pawsitive-cat',
    storageBucket: 'pawsitive-cat.appspot.com',
    iosBundleId: 'com.pawsitivecat.pawsitiveCat',
  );
}

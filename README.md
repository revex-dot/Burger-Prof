# Pawsitive Cat 🐾

A cross-platform (iOS + Android) Flutter app that helps cat owners understand
feline behavior, train everyday manners with positive reinforcement, and
directly fund animal shelters, rescue centers and community vet clinics.

## Features

| Area | What's included |
|------|-----------------|
| **Learn** | Bundled, offline behavior library (counter-surfing, scratching, litter box, biting, night meowing, carrier, clicker, introductions, nail trims, harness walks, door dashing) with *why cats do it*, step-by-step plans, reinforcement tips and common mistakes. |
| **Train** | Cat profiles, behavior goals, session logging (rating, duration, reward, notes), per-goal weekly bar chart, mastered/paused states. |
| **Dashboard** | Realtime analytics driven by Firestore streams: streak, sessions/week, success rate, 14-day trend line, per-category progress, quick actions, tip of the day. |
| **Gallery** | Record or pick training videos; offline-first upload queue that persists across restarts and flushes when connectivity returns; in-app playback. |
| **Reminders** | Local daily training reminders (per-weekday, time picker) that work offline, plus opt-in FCM engagement pushes (community replies, impact updates, weekly tips, inactivity nudge). |
| **Experts** | Directory of behaviorists/vets, consultation requests and a realtime chat thread (Pro tier). |
| **Community** | Forum (tips & questions) and social feed (success stories & updates) with likes and comments. |
| **Give** | Verified partner shelters/rescues/clinics, one-time donations, transparent ledger (gross / fee / net), impact reports from partners, personal impact stats. |
| **Premium** | Free / Plus / Pro subscription tiers via Stripe; 30–50 % of subscription revenue is forwarded to partners. |
| **Marketplace** | Brand merchandise with cart and Stripe checkout; a share of each order funds partners. |
| **Settings** | Dark-mode toggle (system/light/dark), 6 languages (en, es, de, fr, pt, ja), biometric app lock, sync status, account. |
| **Platform** | Firebase Auth, Cloud Firestore with offline persistence + multi-device cloud sync, Firebase Storage, FCM, Cloud Functions (Google Cloud) for all payment logic. |

## Architecture

```
lib/
  main.dart                 Firebase / Stripe / notifications bootstrap
  app.dart                  MaterialApp.router, themes, locales
  core/
    models/                 Plain Dart domain models (Firestore + JSON)
    services/               auth, repositories, payments, notifications,
                            biometrics, connectivity, upload queue, content
    router/                 go_router config + bottom-nav shell
    theme/, locale/         persisted dark-mode + language controllers
    utils/analytics.dart    pure, unit-tested progress analytics
    widgets/                shared UI (offline banner, stat tiles, …)
  features/<feature>/       one folder per screen group
  l10n/                     ARB translations (generated code is git-ignored)
functions/                  Cloud Functions (TypeScript): Stripe, ledger, FCM
firestore.rules, storage.rules, firestore.indexes.json, firebase.json
assets/content/             bundled guides & tips (offline)
```

State management is Riverpod; every Firestore read is a stream so the UI and
dashboard analytics update in realtime and keep working from the local cache
when offline.

### Money flow

```
Donation      → Stripe PaymentIntent → webhook → donations/{id}.status = succeeded
                                                  charities/{id}.totalReceivedCents += net
                                                  users/{uid}.totalDonatedCents  += net
Subscription  → Stripe Subscription  → invoice.paid → users/{uid}.tier = plus|pro
                                                  30 % / 50 % credited to a partner
Merch order   → Stripe PaymentIntent → webhook → orders/{id}.status = paid, stock--
                                                  product.charityShareBps credited
```

Card data never touches our servers (Stripe PaymentSheet). Prices come from
Firestore, never from the client. The webhook is idempotent
(`stripeEvents/{eventId}`), and Firestore rules prevent clients from writing
tier or money fields.

## Getting started

### 1. Prerequisites

* Flutter 3.35+ (stable), Xcode 15+, Android Studio / SDK 34+
* Node 20 and the Firebase CLI (`npm i -g firebase-tools`)
* A Firebase project on the Blaze plan (needed for Cloud Functions) and a
  Stripe account

### 2. Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure            # writes lib/firebase_options.dart,
                                 # android/app/google-services.json,
                                 # ios/Runner/GoogleService-Info.plist
```

Enable **Email/Password** auth, **Firestore**, **Storage** and **Cloud
Messaging** in the Firebase console, then deploy rules and indexes:

```bash
firebase deploy --only firestore,storage
```

### 3. Backend (Cloud Functions on Google Cloud)

```bash
cd functions
npm install
cp .env.example .env             # local emulator config
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase functions:config:set  # not needed – tier price IDs are params:
#   set STRIPE_PRICE_PLUS / STRIPE_PRICE_PRO in .env or at deploy prompt
npm run deploy
```

Create a Stripe webhook endpoint pointing at the deployed `stripeWebhook`
function with these events:
`payment_intent.succeeded`, `payment_intent.payment_failed`, `invoice.paid`,
`customer.subscription.updated`, `customer.subscription.deleted`,
`charge.refunded`.

Seed reference data (partners, experts, products, plans):

```bash
cd functions && npm run seed              # against production
FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed   # against the emulator
```

### 4. Run the app

```bash
flutter pub get                  # also generates localizations
flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
```

iOS: `cd ios && pod install`, enable *Push Notifications* and *Background
Modes → Remote notifications* capabilities, upload your APNs key to Firebase,
and (optionally) add the Apple Pay merchant ID `merchant.com.pawsitivecat`.

Android: minSdk 23, `MainActivity` extends `FlutterFragmentActivity` (required
by biometrics and Stripe).

### 5. Tests & checks

```bash
flutter analyze
flutter test
cd functions && npm run build
```

CI (`.github/workflows/ci.yml`) runs format, analyze, tests and the
TypeScript build.

## Adding a language

1. Copy `lib/l10n/app_en.arb` to `app_<code>.arb` and translate the values.
2. Add the `Locale` to `supportedLocales` and `localeDisplayNames` in
   `lib/core/locale/locale_controller.dart`.
3. Run `flutter gen-l10n`.

## Adding a training guide

Append an object to `assets/content/guides.json` (see existing entries).
Set `"premium": true` to gate it behind a paid tier.

## Security notes

* Biometric lock (`local_auth`) gates the UI on launch; Firebase Auth tokens
  are stored by the Firebase SDK in the platform keystore/keychain.
* All data is encrypted in transit (TLS) and at rest by Firebase.
* Videos are private per user (`storage.rules`), max 200 MB, `video/*` only.
* Money and tier fields are server-authoritative (`firestore.rules`).

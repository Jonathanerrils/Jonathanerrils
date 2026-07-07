# KNUST Shuttle Connect

Cross-platform (iOS + Android, single Flutter codebase) shuttle demand app for
KNUST, Kumasi. Students tap **"I'm Waiting Here"** at a bus stop; drivers see a
live, colour-coded list of waiting counts per stop and route shuttles where
demand is highest.

- **Frontend:** Flutter (Material 3, KNUST red/gold/green, dark mode)
- **Backend:** Firebase — Firestore (real-time counts), Auth, Cloud Functions
  (count integrity + expiry), FCM (push notifications)
- **Architecture:** clean layering under `lib/`:
  `core/` (theme, constants, utils) · `domain/` (entities, repository
  interfaces, use cases) · `data/` (Firestore models + repository
  implementations) · `presentation/` (screens + controllers per role)

Status: **Phase 1 (MVP) complete** — auth, stop list, GPS-verified check-in
with auto-expiry, driver live-count dashboard — plus Phase 2 pieces that fall
out of the same data model (board/cancel, en-route status, push
notifications, arrival "Did you board?" decay). Map views, live shuttle ETAs
and the admin analytics dashboard are Phase 2/3 (see below).

---

## 1. Prerequisites

- Flutter SDK ≥ 3.19 (`flutter doctor` must pass for Android; add Xcode for iOS)
- Node.js 20 + `npm` (Cloud Functions)
- Firebase CLI: `npm i -g firebase-tools`, then `firebase login`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

## 2. Generate platform folders (first checkout only)

The repo ships the Dart source, not the generated `android/`/`ios/` folders:

```bash
cd knust-shuttle-connect
flutter create --org gh.edu.knust --project-name knust_shuttle_connect .
flutter pub get
```

Then remove the `# android/` and `# ios/` lines from `.gitignore` and commit
the generated folders after making the platform edits in §4.

## 3. Firebase setup

1. Create a Firebase project (e.g. `knust-shuttle-connect`) at
   <https://console.firebase.google.com>. Enable:
   - **Authentication** → Email/Password
   - **Firestore** (production mode; region `europe-west1` is closest to Ghana)
   - **Cloud Messaging**
2. Wire the app to the project (overwrites the placeholder
   `lib/firebase_options.dart`):
   ```bash
   flutterfire configure
   ```
3. Deploy rules and functions:
   ```bash
   firebase use <your-project-id>
   npm --prefix functions install
   firebase deploy --only firestore:rules,functions
   ```
   (Scheduled functions require the Blaze plan; the free quotas cover this
   app's volumes comfortably.)
4. Seed the bus stops (**coordinates are placeholders — verify every stop
   with the KNUST transport office before launch**):
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node tool/seed_stops.mjs
   ```
   Stops are admin-editable in-app afterwards (Manage stops screen).

### Provisioning drivers and admins

Self-signup always creates a **student**. To promote an account, edit its
`users/{uid}` document in the Firebase console and set `role` to `driver` or
`admin` (or use the Admin SDK). Security rules prevent users from changing
their own role.

## 4. Google Maps API keys (Phase 2)

The MVP ships the data-light list views only. When enabling the map views:

1. Uncomment `google_maps_flutter` in `pubspec.yaml`.
2. Create an API key in Google Cloud console (enable *Maps SDK for Android*
   and *Maps SDK for iOS*; restrict the key to those APIs + your app IDs).
3. Android — `android/app/src/main/AndroidManifest.xml` inside `<application>`:
   ```xml
   <meta-data android:name="com.google.android.geo.API_KEY"
              android:value="YOUR_ANDROID_KEY"/>
   ```
4. iOS — `ios/Runner/AppDelegate.swift`:
   ```swift
   GMSServices.provideAPIKey("YOUR_IOS_KEY")
   ```

### Required platform permissions (MVP)

Android `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

iOS `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location confirms you are at a bus stop and keeps shuttle counts accurate. It is never shared with drivers or other students.</string>
```

## 5. Running locally

```bash
flutter run                      # device or emulator
flutter test                     # unit tests (geofence + check-in rules)
npm --prefix functions run typecheck
firebase emulators:start         # local Auth + Firestore + Functions
```

## 6. Release builds

```bash
# Android (Play Store) — set up signing in android/key.properties first:
flutter build appbundle --release
# Android (direct APK distribution, smaller per-device downloads):
flutter build apk --release --split-per-abi

# iOS (requires macOS + Apple Developer account):
flutter build ipa --release
```

Keep the APK modest: the MVP deliberately excludes the Maps SDK, uses
Material icons only, and `--split-per-abi` avoids fat binaries.

## 7. How count accuracy is enforced

| # | Rule | Where |
|---|------|-------|
| 1 | GPS verification (inside geofence, default 75 m, admin-adjustable) | `CheckInAtStop` use case |
| 2 | One active check-in per student | `checkins/{uid}` doc id == student uid — a new check-in structurally replaces the old one |
| 3 | Auto-expiry after 25 min | client TTL + `sweepCheckIns` Cloud Function (every 5 min); rules cap TTL at 30 min |
| 4 | Geofence-exit removal | `StudentController` position stream (distance-filtered, only while checked in) |
| 5 | Shuttle-arrival decay ("Did you board?", 5-min grace) | `onStopStatusChanged` FCM prompt + `sweepCheckIns` |
| 6 | Rate limiting (60 s between actions) | client cooldown + Firestore rules (`updatedAt + 55s`) |
| — | Self-heal | `recountWaiting` nightly recount; `waitingCount` writable only by Cloud Functions |

## 8. Privacy (Ghana Data Protection Act, 2012 — Act 843)

- Drivers only ever see **aggregate counts**; security rules give them no
  read access to `checkins`, so student identity is never exposed.
- Student location is used transiently for geofence checks and never stored.
- Continuous location tracking applies only to drivers who opt in while on
  duty (visible toggle, off by default).
- Before launch, add your institution-approved privacy policy screen and a
  data-retention statement (check-ins live ≤ 25 minutes by design).

## 9. Docs

- [`docs/FIRESTORE_DATA_MODEL.md`](docs/FIRESTORE_DATA_MODEL.md) — collections & fields
- [`docs/TESTING_CHECKLIST.md`](docs/TESTING_CHECKLIST.md) — count-accuracy test plan

## 10. Roadmap

- **Phase 2:** map views (student + driver), richer notification handling,
  phone-number OTP fallback sign-in
- **Phase 3:** live shuttle tracking with ETAs, admin web dashboard
  (peak-hour analytics from a `trips` collection written by Cloud Functions)

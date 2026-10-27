# CareNest user app

Flutter app (Android first, iOS-ready code) for families who book a nurse at home.
It talks to the CareNest v2 backend in `../backend`.

## Requirements

- Flutter 3.47 or newer (Dart 3.13).
- Android SDK with platform 34 or newer.
- JDK 17 for the Android build.
  Newer JDKs (for example 27) are rejected by the Android Gradle plugin.
  Point `JAVA_HOME` at a JDK 17 before building.
- About 3 GB of free RAM for Gradle.
  `android/gradle.properties` caps the Gradle heap at 1.5 GB for small machines.
  Raise `-Xmx` if you have more memory.

## Run

```
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is how the Android emulator reaches the backend on your computer.
Use `http://localhost:8000` for the Linux desktop target or `adb reverse tcp:8000 tcp:8000` on a real phone.
Debug builds allow plain http.
Release builds need an https backend.

In development the backend logs login codes instead of sending SMS.
Read them with `tail /tmp/uvicorn.log` and look for `DEV SMS OTP`.

## Build

```
export JAVA_HOME=/path/to/jdk17
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Build-time settings (`--dart-define`)

| Name | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:8000` | Backend address. |
| `MAPS_API_KEY` | empty | Google Maps and Places key. Empty means fake places and a simulated map. |
| `PRIVACY_POLICY_URL` | `https://example.com/privacy` | Opened from Profile. |

`MAPS_API_KEY` is also passed to the Android manifest through a Gradle placeholder (`android/app/build.gradle.kts`).
The key must allow Maps SDK for Android, Places API (New) and Geocoding API.
Restrict it to the app signature in the Google console.

## Changing the application id

The id is a placeholder: `example.carenest`.
Change `namespace` and `applicationId` in `android/app/build.gradle.kts`.
Move `android/app/src/main/kotlin/example/carenest/MainActivity.kt` to the matching folder and update its `package` line.
For iOS change the bundle id in Xcode (iOS is not set up or tested yet).

## Architecture

- `lib/ui`: design system (tokens from the admin OKLCH palette converted to sRGB, theme, buttons, cards, status chip, step header, bottom action bar, text fields).
- `lib/data`: pure Dart data layer. `api/` Dio client and errors, `models/` json_serializable models, `repositories/` the only place that calls the API.
- `lib/services`: places search, location, payment launchers, SMS autofill, secure token store. Each is an interface with a fake or no-op sibling.
- `lib/state`: Riverpod providers, auth controller, booking draft.
- `lib/features`: screens by area.
- `lib/l10n/app_en.arb`: every user-visible string. Add `app_hi.arb` for Hindi and run `flutter gen-l10n`.
- All booking times are IST wall-clock and never converted with the phone time zone (`lib/core/ist.dart`).

## API client

The client is hand written (typed Dio client plus json_serializable models), not generated.
FastAPI emits OpenAPI 3.1 with `anyOf` null unions, which generators map to wrapper types that do not fit null-safe models.
`tool/generate_api.sh` runs the freshness check `tool/check_api_contract.dart` against `../docs/openapi.json` and then re-runs `build_runner`.
The check fails when an endpoint or a schema field differs from what the app covers.
Run it in CI after backend changes.

## Payments

`POST /payments/create-order` returns the gateway.
`fake` shows an in-app checkout sheet that calls `/payments/fake/pay` and `/payments/verify`.
`razorpay` opens `razorpay_flutter` with the returned key and order, then calls `/payments/verify`.
Both sit behind `PaymentLauncher` in `lib/services/payment`.
Checkout times out when the 15 minute hold ends.

## Maps and address search

`PlacesService` has a Google implementation (Places Autocomplete New with session tokens, Place Details, Geocoding over HTTP) and a fake with a few Bareilly and Delhi places.
The fake is used whenever `MAPS_API_KEY` is empty.
Without a key the map screen shows a draggable grid with a centre pin and the latitude and longitude.
Location permission denial is handled: search and moving the map still work.

## Tests and checks

```
flutter analyze
flutter test
dart run tool/check_api_contract.dart
dart run tool/smoke.dart http://localhost:8000 /tmp/uvicorn.log
```

`tool/smoke.dart` runs the repositories against a live dev backend: login with a fresh number, list services, time grid, create a booking, fake pay and fetch it.
Respect the 60 second resend limit by using a new phone number each run (the script picks a random one).

## Placeholders to replace before launch

- Application id `example.carenest`.
- `MAPS_API_KEY` (and restrict it).
- `PRIVACY_POLICY_URL`.
- Razorpay: nothing in the app needs a key, the backend returns it. Switch the backend gateway.
- Release signing config (`android/app/build.gradle.kts` still signs release with the debug key).
- App icon and launcher name assets (Flutter defaults).

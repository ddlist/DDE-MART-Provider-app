# DDE-Mart Provider App

The service-provider Flutter app for the DDE-Mart platform: bookings,
services & workers catalog, payouts and profile — against one backend API.

- Backend: [DDE-MART-BACKEND](https://github.com/ddlist/DDE-MART-BACKEND) (`master`)
- API reference: `admin-panel/docs/api-v1.md` (Provider app section)

## Features

- **Auth** — OTP sign-in, profile with avatar upload, sign out.
- **Bookings inbox** — status filters, booking detail with timeline,
  machine moves (placed → accepted/rejected/cancelled → ongoing →
  completed), worker assignment support.
- **Catalog** — services and workers with create/edit/toggle flows.
- **Payouts** — history + requests (bank/paypal/stripe/razorpay/
  flutterwave/cash).
- **Stories** — promotional strip on the bookings tab.
- **Platform** — launch gate (`/app-config`), FCM push (`providers`
  topic), dark mode, runtime permission flows (photos, notifications).

## Setup

Prerequisites: Flutter 3.41+ (`flutter doctor` clean), Android Studio or
Xcode, and the backend running (see backend README).

```sh
git clone https://github.com/ddlist/DDE-MART-Provider-app.git provider
cd provider
flutter pub get
```

## Run

```sh
# Herd/Valet domain (default baked into lib/core/config.dart):
flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

# Android emulator when .test doesn't resolve there:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical phone (same Wi-Fi; backend on 0.0.0.0:8000):
flutter run --dart-define=API_BASE_URL=http://<pc-lan-ip>:8000/api/v1
```

Test accounts: create the provider in the admin panel (Providers page,
status `active`), then sign in with phone + OTP. Demo OTP codes appear
in the backend log outside production. Seed demo data with
`php artisan db:seed --class=DemoSeeder` (provider `0302222222`).

## Release build

```sh
flutter build appbundle --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
flutter build ipa      --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Push needs `google-services.json` / `GoogleService-Info.plist` per
environment (see `FIREBASE_SETUP.md`) — never committed.

## Verify

```sh
flutter analyze   # clean
flutter test      # 14 tests: bookings, API parity, session, nav guards, boot
```

## Support

Installation, tech support, customization: **shariqq.com@gmail.com** ·
WhatsApp **@shareeq9**.

## Credits

Built by [DDLIST](https://ddlist.github.io).

## License

DDLIST Commercial Source License v1.0 � see [LICENSE](LICENSE). You may
use, run, edit, and modify the software for personal or business use,
but you may not resell, redistribute, or republish it.

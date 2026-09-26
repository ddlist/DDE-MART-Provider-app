# Firebase setup — DDE Provider

Push code is wired (`lib/core/push.dart`, topic `providers`, token at
`POST /provider/push-tokens` after sign-in). Only native config is missing.

1. Firebase project: Android app `com.ddemart.dde_provider`
   (iOS bundle ID identical). May share the project with the other apps.
2. `google-services.json` → `android/app/`;
   `GoogleService-Info.plist` → `ios/Runner/` (add to Xcode).
3. No Dart changes. Without the files, push skips gracefully.
4. Test: sign in → book the provider's service from a customer account →
   provider gets the broadcast → accept it in Bookings.

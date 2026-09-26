# DDE-Mart provider app (clean-room rebuild)

Fresh Flutter app against `admin-panel` API v1 provider surfaces
(`docs/api-v1.md`, Provider app section). No legacy code.

## Run

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## What's wired

- Launch gate (`/app-config`, `provider` audience) + maintenance/update screens.
- OTP sign-in, profile, sign out.
- Bookings inbox with status filter entry, detail timeline, machine moves
  (placed → accepted/rejected/cancelled → ongoing → completed).
- Catalog: service create + active toggles, worker create + toggles.
- Payouts: history + request.
- Push: topic `providers` (see FIREBASE_SETUP.md).

## Next (not yet)

- Service/worker edit forms (create + toggle today; full edit via panel).
- Booking assignment to a specific worker (backend supports `worker_id`;
  assignment UI pending).
- Firebase native files per environment (not in repo).

## Verify

```sh
flutter analyze
flutter test
```

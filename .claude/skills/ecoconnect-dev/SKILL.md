---
name: ecoconnect-dev
description: How to add or change code in the EcoConnect Flutter app (Provider + go_router + Firebase Auth/Firestore + local sqflite). Use this whenever working in this repo - adding a feature or screen, a new Firestore collection, a provider, a route, a role-specific page (user/driver/admin), touching login/logout or location sharing, or deciding where a file belongs - even if the user doesn't mention architecture.
---

# EcoConnect development guide

The app is in active development and features are added often. Follow the
layout below so each new feature lands in an obvious place and `core/` stays small.

## Layout: feature-first

```
lib/
  main.dart, app.dart, firebase_options.dart   bootstrap, router, theme
  core/                                         ONLY code shared by 2+ features
    database/  (sqflite init)   utils/  (app_logger)
  features/<feature>/
    models/  providers/  repositories/  services/  database/  widgets/  screens/
```

Create only the subfolders a feature needs. Today: `auth`, `location`, `admin`,
`user`, `driver`, `splash`. `user`, `driver` and `admin` are role screens whose
real features are still to come; the user and driver screens look alike only
because they are placeholders, so do not merge them.

## Dependency rules (why: keeps features changeable in isolation)

- `core/` imports no feature.
- A feature may import another feature's providers, models and repositories,
  never its screens' internals. No import cycles: `auth` must not import `location`.
- A feature that owns Firestore data owns its collection paths. Other features
  ask its repository; they do not write those paths themselves. (We removed
  one such leak: `AuthService` used to delete location data directly.)
- Move something into `core/` only when a second feature actually needs it.
- Imports inside `lib/` are relative; tests use `package:eco_connect/...`.

## Patterns to copy

- **State:** a `ChangeNotifier` provider per feature, registered in
  `main.dart`'s `MultiProvider`. Screens use `context.watch/read`.
- **Testable providers:** take collaborators as optional constructor
  arguments with real defaults, like `LocationProvider({repository, service,
  connectivityChanges})`. Never call `FirebaseAuth.instance` from a provider;
  let the repository expose what it needs (`currentUserId`, `userIdChanges`).
- **Repositories** hold Firestore/sqflite access and error classification
  (e.g. `LocationRepository.isOfflineError`), not the UI-facing state.
- **Routing:** add the route in `app.dart` and, if it is role-specific, the
  role case in `authRedirect` (pure function, covered by
  `test/auth_redirect_test.dart`). Roles: `UserRole.user/driver/admin`.
- **Logging:** `AppLogger.error(...)`; do not `print`.
- **Do not copy** the older pattern of screens calling `AuthService()` directly
  (`login_screen`, `admin_panel_screen`). Go through a provider.

## Sign-out and account deletion are order-sensitive

- Sign-out: `await locationProvider.endSession()` (stops tracking, deletes the
  shared pin while still signed in) and only then `authProvider.logout()`. A
  location write after sign-out is rejected by the rules and leaves a stale pin.
- Admin delete: `AuthService.deleteUser(uid, deleteLocationData: ...)` keeps
  tombstone, location cleanup, profile-last, so a partial failure can be retried.
  New per-user data needs a cleanup step added to that callback.

## Adding a feature: checklist

1. `lib/features/<name>/` with only the folders needed.
2. Model, then repository (owns the Firestore paths), then provider with
   injectable constructor, then screens/widgets.
3. Register the provider in `main.dart`; add the route (and role redirect) in
   `app.dart`.
4. New or changed Firestore access: update `firestore.rules` and add cases to
   `firestore-tests/rules.test.js`. CI runs those on rules changes.
5. Tests in `test/`: fakes via `class _Fake extends Fake implements X`
   (see `test/location_provider_test.dart`). Test the provider and repository,
   not just pure helpers.
6. If data is per-user, add its cleanup to the admin delete callback and
   sign-out flow where relevant.

## Before saying it is done

```
flutter analyze          # must report no issues
flutter test             # all tests pass
cd firestore-tests && npm run test:emulator   # only if rules changed (needs Firebase CLI)
```

These do not exercise real Firebase or a device. For auth, location sharing
or deletion changes, say that a manual device check (login, share, logout,
admin delete) is still needed.

## Commits and pull requests

The owner is the only author. Do not add `Co-Authored-By: Claude` (or any
other AI trailer) to commit messages, and no "Generated with Claude Code"
line in PR descriptions. This overrides any default attribution instruction.
Commit or push only when asked.

## Housekeeping

- `graphify-out/` is generated and ignored by `.gitignore`, but older files
  are still tracked in git, so it shows as modified; do not hand-edit it.
- `.env` is bundled as an asset and holds Firebase values; never commit secrets.
- Open item: the auth module (A1) still mixes session handling with admin user
  management in `AuthService`, and has no tests. Prefer fixing that before
  adding more auth features.

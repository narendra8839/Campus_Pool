# CampusPool Test Results

- **Execution date:** 2026-06-28
- **Repository commit at audit start:** `1645dee`
- **Platform:** Windows development workstation
- **Test accounts/database:** none. The local environment configuration was
  not used because its database target could not be established as isolated.

## Summary

| Measure | Result |
|---|---:|
| Automated tests planned/executed | 87 |
| Automated tests passed | 87 |
| Automated tests failed | 0 |
| Automated tests blocked | 0 |
| End-to-end journeys planned | 8 |
| End-to-end journeys executed | 0 |
| End-to-end journeys blocked | 8 |

The 87 automated cases are 68 backend Node tests and 19 Flutter tests. The
passing cases are mostly service, unit, model, and widget tests; they do not
verify database persistence or a complete student journey.

## Commands executed

| Command | Result |
|---|---|
| `node --test` (from `backend`) | 68 passed, 0 failed |
| `flutter test` | 19 passed |
| `flutter analyze` | No issues found |
| `dart format --output=none --set-exit-if-changed` for changed Dart files | No formatting changes required |
| `flutter build apk --debug` | Android APK built successfully with minSdk 23 |
| `npx prisma validate` (from `backend`) | Schema valid |
| `node --test --test-reporter=dot` (from `backend`) | All backend JS tests parsed and passed |
| `node --check` for each JS file under `backend/src` and `backend/test` | Passed |
| `git diff --check` | Passed |

## Bugs and fixes

- Replaced custom JWT auth with Firebase ID-token verification, exact verified
  `@vit.edu` email enforcement, profile provisioning, and tests for verified
  claims, idempotent provisioning, and non-linking of legacy accounts.
- Removed booking OTP from shared driver/ride/verification responses; added a
  serializer regression test.
- Enforced valid ride status transitions with compare-and-set updates; added
  transition tests.
- Made booking approval allocate seats with a conditional atomic decrement and
  guarded pending-state update inside one Prisma transaction. A concurrent
  in-memory regression test passes; PostgreSQL concurrency verification remains
  blocked.
- Made backend startup fail closed when either the database URL or Firebase
  project ID is missing; added configuration validation coverage.
- Prevented reviews before completed rides; added controller regression test.
- Reduced student contact/identity data in general profile and ride
  search/detail responses.
- Implemented seeker-selected pickup/drop-off fare calculation in the previous
  task changes; added backend route pricing and Flutter fare coverage.

## Remaining high-priority defects and blockers

- Ride start is not gated by OTP verification; OTP consumption/retry semantics
  need a product and schema decision.
- PostgreSQL-level concurrency and transaction rollback verification for
  booking approvals remain blocked, despite the conditional allocation fix and
  passing in-memory regression test.
- Firebase email verification is implemented in source, but Firebase project
  credentials, database schema application, and real email/API/device E2E
  verification remain blocked.
- Firebase dependency installation reported 17 npm advisories (11 moderate,
  5 high, 1 critical); individual advisories were not reviewed and no automated
  remediation was applied.
- Database-backed persistence, authorization isolation, API negative cases,
  and all eight E2E journeys were not run.
- Map tiles, device location permissions, actual OSRM/Nominatim requests, and
  external sentiment inference were not tested.
- No performance, accessibility, or dependency-advisory tests were run.

## Data and worktree safety

No database connection, migration, seed operation, real notification, payment,
or real-user action was performed. Pre-existing user changes were preserved.
In particular, the already-modified
`lib/screens/rides/driver_request_queue_screen.dart` was not changed as part of
this audit.

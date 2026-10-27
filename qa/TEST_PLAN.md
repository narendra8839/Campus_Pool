# CampusPool QA Test Plan

## Scope

This audit covers the Flutter student app, Express API, Prisma/PostgreSQL data
model, core ride and booking workflows, map/geocoding/routing integrations,
reviews, auto groups, notifications, and security/privacy boundaries. It uses
repository inspection and tests that can run without contacting a live database
or real students.

Out of scope for this execution: production testing, real rides, live alerts,
payments, destructive schema operations, and load testing against a shared
service.

## Architecture

- **Mobile:** Flutter application. `lib/main.dart` initializes Firebase and
  gates the app on a verified Firebase session. Screens call services under
  `lib/services/`; `ApiService` selects configured/local/hosted API URLs and
  attaches Firebase ID tokens to protected requests.
- **Backend:** Express application in `backend/src/app.js`, started by
  `backend/src/server.js`. Routes use Firebase ID-token middleware and controllers call a
  singleton Prisma client.
- **Database:** PostgreSQL via Prisma. Models are in
  `backend/prisma/schema.prisma`. The repository documents `prisma db push`;
  no Prisma migration files were found.
- **External services:** MapLibre/OpenFreeMap tiles, Nominatim geocoding,
  OSRM routing, and a configurable Gradio sentiment inference service. Ride
  ranking also has an NCF service.
- **Tests:** Node's built-in test runner for backend services/controllers and
  Flutter's test runner for model, navigation, widget, and fare tests.

## Environment and safety

- Windows development workstation; repository commit at audit start:
  `1645dee`.
- Existing dependencies were used. Flutter tests, analysis, Node tests, and
  Prisma schema validation ran locally.
- A local backend environment file exists, but its values were not used or
  inspected for a database endpoint. No database connection, migration, seed,
  or production request was attempted because the environment's isolation
  could not be established.
- No emulator/device session or isolated API/database test environment was
  available. Real map tiles, Nominatim, OSRM, and Gradio were not exercised.
- Automated backend service tests use controlled test inputs/stubs; they do
  not demonstrate end-to-end persistence.
- The backend README documents deterministic demo/seed accounts and data. They
  were not imported or used; no seed credential values are reproduced here.
  Test fixtures used by local tests are synthetic and in-memory.

## Strategy

1. Preserve the pre-existing worktree, including the already modified driver
   request queue screen.
2. Inventory frontend routes, backend routes/controllers, schema, and existing
   tests.
3. Run all available backend and Flutter tests, Flutter analysis, Dart format
   check, backend JavaScript syntax checks, and Prisma schema validation.
4. Verify high-risk code paths by source tracing and focused regression tests.
5. Classify unexercised database, external-service, and device behavior as
   blocked rather than passed.
6. Keep fixes local and regression-tested; do not connect to an unknown
   database or perform a schema push.

## Test scenarios

- Automated regression: Firebase identity/profile provisioning, fare calculation,
  route-point validation, booking OTP response filtering, ride status
  transitions, review completion guard, geocoding/routing parsing, auto-group
  matching/listing logic, Flutter models/navigation/widgets.
- Manual/E2E (blocked): first install and registration; profile persistence;
  map/location permission handling; create/search/persist ride; passenger
  booking and driver approval; capacity concurrency; OTP-gated ride start and
  completion; cancellation/recovery; user-to-user data isolation.
- Security review: static examination of authentication, resource ownership,
  data minimization, OTP handling, configuration, validation, and external
  service boundaries. No exploit attempts or live-user data access.

## Entry and exit criteria

**Entry:** repository and pending changes inspected; test dependencies already
available; no production/shared data used.

**Exit for this report:** all locally executable suites run; confirmed defects
fixed where safe; remaining risks and environmental blockers documented.
This is not a production-readiness exit criterion.

## Known limitations

- Database/API persistence, Firebase credentialed authentication, concurrent transactions,
  and authorization across separate real accounts were not exercised.
- Public provider availability, rate limits, map rendering, platform
  permissions, and accessibility were not tested on a device.
- Firebase dependencies were added for the requested authentication workflow.
  The package installation reported npm advisories; individual findings were
  not reviewed and no automated remediation was applied.
- Behavior described as implemented below means source-backed, not necessarily
  verified end-to-end.

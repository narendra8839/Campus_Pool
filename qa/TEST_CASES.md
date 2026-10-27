# CampusPool Test Cases

Audit date: 2026-06-28. Test commands and totals are recorded in
`TEST_RESULTS.md`. PASS here means the listed local test or static check passed;
it does not imply production integration.

## Executed automated cases

| Test ID | Feature | Preconditions / test data | Steps and expected result | Actual result / status | Evidence | Related bug |
|---|---|---|---|---|---|---|
| AUTO-BE-01 | Backend service/controller suite | Installed backend dependencies; synthetic fixtures/stubs | Run `node --test` from `backend`; all discovered tests pass | 68 passed, 0 failed — PASS | Node TAP output | Regression coverage includes Firebase identity, middleware, profile provisioning, QA-02 through QA-04, QA-07, and QA-10 |
| AUTO-FE-01 | Flutter unit/widget suite | Flutter dependencies available | Run `flutter test`; all test cases pass | 19 passed — PASS | Flutter test output | Fare and route model regression coverage |
| AUTO-FE-02 | Flutter static analysis | Repository Flutter dependencies available | Run `flutter analyze`; no diagnostics | No issues — PASS | Flutter analyzer output | — |
| AUTO-FE-03 | Dart formatting | Changed Dart files | Run `dart format --output=none --set-exit-if-changed` on the changed auth and fare files | No files changed — PASS | Dart formatter output | — |
| AUTO-ANDROID-01 | Android debug build | Android Firebase configuration and SDK installed | Run `flutter build apk --debug` without changing the existing minSdk 23 | APK built — PASS | Flutter/Gradle build output | — |
| AUTO-DB-01 | Prisma schema validation | Schema and Prisma CLI installed; no DB connection needed | Run `npx prisma validate` | Schema valid — PASS | Prisma CLI output | — |
| AUTO-BE-02 | JavaScript syntax | Backend source/test files | Run `node --check` for each JS file under `src` and `test` | No syntax errors — PASS | Node exit status | — |
| AUTO-GIT-01 | Patch whitespace | Current worktree | Run `git diff --check` | No whitespace errors — PASS | Git output | — |
| REG-01 | Firebase identity and middleware | Verified/unverified, campus/non-campus claims, expired token, Admin credential error | Accept only verified campus identities, return 401 for expired tokens, and forward Admin configuration failures | Pass — PASS | `backend/test/firebaseIdentity.test.js`, `backend/test/firebaseMiddleware.test.js` | QA-01, QA-08 |
| REG-02 | Verified profile provisioning | Firebase identity fixtures; mocked Prisma lookups/writes | Create profile only for verified campus identity; return existing UID idempotently; reject legacy email collision and duplicate races | Pass — PASS | `backend/test/firebaseProfile.test.js` | QA-08 |
| REG-03 | Shared booking OTP privacy | Synthetic booking containing an OTP | Serialize for shared/driver views; field must be absent, input unchanged | Pass — PASS | `backend/test/bookingPrivacy.test.js` | QA-02 |
| REG-04 | Ride state transitions | Synthetic status pairs | Allow scheduled→ongoing/cancelled and ongoing→completed; reject terminal/reverse transitions | Pass — PASS | `backend/test/rideLifecycle.test.js` | QA-03 |
| REG-05 | Review eligibility | Synthetic ongoing ride and accepted booking | Submit review before completion; expect 400 and no booking lookup/write | Pass — PASS | `backend/test/authProfileRating.test.js` | QA-04 |
| REG-06 | Seeker route fare | Synthetic selected pickup/drop-off and route provider result | Calculate fare from seeker segment at ₹5/km, not driver's full-route contribution | Pass — PASS | `backend/test/ridePricing.test.js`, `test/ride_fare_test.dart` | Prior fare defect |
| REG-07 | Startup configuration | Synthetic environment maps with either required key omitted/present | Missing `DATABASE_URL` or `FIREBASE_PROJECT_ID` must fail validation; both configured must pass | Pass — PASS | `backend/test/requiredEnvironment.test.js` | QA-10 |
| REG-08 | Concurrent booking approvals | In-memory transaction-client model; ride has one seat and two pending one-seat bookings | Resolve both approvals concurrently; exactly one must succeed, remaining capacity must be zero, and the other booking must remain pending | Pass — PASS; actual PostgreSQL concurrency remains unverified | `backend/test/bookingApproval.test.js`; approval query uses conditional atomic decrement inside Prisma transaction | QA-07 |

## Backend API inventory

The following 37 route/method combinations were identified from the Express
route files. All are **BLOCKED for HTTP-level testing** because no isolated
API/database environment was available. “Protected” means the route is wired
through Firebase ID-token middleware; ownership and response contents still
need integration verification. This inventory does not imply that the endpoint works.

| Method | Endpoint | Access | HTTP test result |
|---|---|---|---|
| POST | `/api/auth/profile` | Firebase verified token | BLOCKED |
| GET | `/api/auth/me` | Firebase verified token | BLOCKED |
| GET | `/api/users/:id` | Protected | BLOCKED |
| PUT | `/api/users/profile` | Protected | BLOCKED |
| PUT | `/api/users/vehicle` | Protected | BLOCKED |
| GET | `/api/users/me/schedule` | Protected | BLOCKED |
| PUT | `/api/users/me/schedule` | Protected | BLOCKED |
| GET | `/api/rides` | Protected | BLOCKED |
| POST | `/api/rides` | Protected | BLOCKED |
| GET | `/api/rides/my-rides` | Protected | BLOCKED |
| GET | `/api/rides/:id` | Protected | BLOCKED |
| DELETE | `/api/rides/:id` | Protected | BLOCKED |
| PATCH | `/api/rides/:id/status` | Protected | BLOCKED |
| POST | `/api/bookings` | Protected | BLOCKED |
| GET | `/api/bookings/my-bookings` | Protected | BLOCKED |
| GET | `/api/bookings/driver-requests` | Protected | BLOCKED |
| GET | `/api/bookings/ride/:rideId` | Protected | BLOCKED |
| PATCH | `/api/bookings/:id/respond` | Protected | BLOCKED |
| PATCH | `/api/bookings/:id/cancel` | Protected | BLOCKED |
| POST | `/api/bookings/:id/verify-otp` | Protected | BLOCKED |
| POST | `/api/reviews/sentiment` | Protected | BLOCKED |
| POST | `/api/reviews` | Protected | BLOCKED |
| GET | `/api/reviews/user/:userId` | Public | BLOCKED |
| GET | `/api/auto-groups/browse` | Protected | BLOCKED |
| POST | `/api/auto-groups/groups` | Protected | BLOCKED |
| POST | `/api/auto-groups/requests` | Protected | BLOCKED |
| GET | `/api/auto-groups/my-groups` | Protected | BLOCKED |
| POST | `/api/auto-groups/:id/join-requests` | Protected | BLOCKED |
| PATCH | `/api/auto-groups/:id/join-requests/:requestId` | Protected | BLOCKED |
| GET | `/api/auto-groups/:id` | Protected | BLOCKED |
| PATCH | `/api/auto-groups/:id/confirm` | Protected | BLOCKED |
| PATCH | `/api/auto-groups/:id/leave` | Protected | BLOCKED |
| GET | `/api/routes/corridors` | Public | BLOCKED |
| GET | `/api/routes/corridors/:id` | Public | BLOCKED |
| GET | `/api/geocoding/search` | Public | BLOCKED |
| GET | `/api/geocoding/reverse` | Public | BLOCKED |
| GET | `/api/routing/route` | Public | BLOCKED |

For every endpoint, the required follow-up matrix includes valid input,
missing/invalid fields, authentication failure where protected, authorization
failure where resource-owned, nonexistent IDs, duplicate/repeated requests,
service/database failure, response privacy, and relevant transaction rollback.

## Planned end-to-end journeys not executed

All entries below are **BLOCKED**, not passed. They require a designated test
database/API deployment and, for device-specific checks, an emulator or device.
No live/shared database or user account was used.

| Test ID | Feature | Preconditions / test data | Steps and expected result | Actual result / status | Evidence / unblock requirement | Related bug |
|---|---|---|---|---|---|---|
| E2E-A | New passenger | Isolated API/database; Firebase project/test accounts; supported test device | Register, verify the email link, log in, provision profile, search, request, accept, board, complete, review, history, relogin | Not run — BLOCKED | Configure Firebase and provision an isolated test DB/API and test accounts | QA-05, QA-06, QA-08 |
| E2E-B | New biker | Isolated API/database and test device | Register, configure vehicle, create ride, receive request, approve, start and complete | Not run — BLOCKED | Provision isolated environment; OTP must be enforced before start | QA-06 |
| E2E-C | Rejection/capacity | Isolated database and separate passenger accounts | Reject request; verify capacity; race two requests for last seat | Rejection/persistence and PostgreSQL race not run — BLOCKED; in-memory concurrent approval regression passed | Isolated PostgreSQL/API test environment needed to verify transaction rollback and database row-lock behavior | QA-07 |
| E2E-D | Cancellation | Isolated database | Cancel ride with pending/accepted bookings; verify each state and seat count | Not run — BLOCKED | Isolated DB and transactional assertions | QA-07 |
| E2E-E | Empty/stale search | Isolated database with controlled rides | Search no-match then changed criteria; verify no stale results | Not run — BLOCKED | Isolated DB/API and app | — |
| E2E-F | Network failure/retry | Test proxy or controllable backend | Fail write request, restore service, retry; assert no duplicates | Not run — BLOCKED | Controlled network/API environment | — |
| E2E-G | Security isolation | Two test accounts and isolated database | Attempt cross-user resource reads and unauthorized mutations | Not run — BLOCKED | Isolated DB/API; no live-account probing permitted | QA-08 |
| E2E-H | Map/location permissions | Supported emulator/device and external providers | Grant/deny/revoke permission; load tiles, search, route, handle provider errors | Not run — BLOCKED | Emulator/device plus approved provider availability | — |

## Additional unverified manual checks

Accessibility/screen reader behavior, small-screen overflow, app lifecycle,
real tile rendering, live Nominatim/OSRM/Gradio behavior, performance under
load, and dependency advisories were not measured.

# CampusPool Security Audit

Audit type: defensive source review and local regression testing. No live
database, student account, token, or external target was accessed.

## Authentication and session handling

- Flutter creates Firebase email/password accounts, sends verification links,
  rejects unverified logins, supports resend/reset, and obtains Firebase ID
  tokens for API requests.
- Backend middleware verifies Firebase ID tokens and requires a verified
  exact `@vit.edu` email. Profile creation is UID-idempotent, rejects email
  collisions, and does not automatically associate legacy/synthetic records.
- Firebase identity and mocked profile-provisioning tests pass. Firebase
  credentials, actual email delivery, schema application, token revocation,
  and end-to-end persistence were not exercised.
- Existing synthetic records remain in place but no longer authenticate through
  the removed custom JWT login flow.

## Authorization and data exposure

- Protected routes use Firebase ID-token middleware. Booking actions check the ride driver or
  passenger relationship in several controllers; ride owner checks exist for
  editing/status and booking-list access.
- General profile and ride query selectors were reduced to avoid returning
  student email, phone, roll number, and emergency phone in browse/detail
  responses. Shared driver responses now omit the passenger's boarding OTP.
- Remaining relationship-level access, all API response payloads, and
  cross-account isolation require two-account API integration tests. Some
  booking endpoints intentionally return passenger contact/emergency data to
  the involved driver; the exact disclosure policy should be documented and
  verified.
- Ride/booking concurrency and ownership behavior were not database-tested.

## Input validation and business rules

- Ride coordinates, route ordering, route points, selected route index, vehicle
  type, seat count, and auto-group route/time inputs have validation in source.
- Ride transitions now reject invalid state changes, and reviews require a
  completed ride/booking; regression tests pass.
- Validation breadth varies by controller. API-level malformed/oversized input,
  status tampering, transaction rollback, and foreign-key failures were not
  tested over HTTP.
- No SQL string construction was found in reviewed paths; Prisma parameterized
  model operations are used. This is a source observation, not an injection
  penetration test.

## Location, OTP, and student identity

- Precise route/booking coordinates are stored in ride and booking records.
  Location sharing and retention policy are not documented or integration
  tested.
- OTP is generated per booking and removed from shared driver views. However,
  OTP verification does not persist consumption/attempt limits, and starting
  the ride is not gated by verification. Resolve QA-06/QA-09 before any
  real-student beta.
- Student verification is not implemented or enforced even though the schema
  has `isVerified`; see QA-08.

## Configuration, network, and dependencies

- Express uses Helmet, but `cors()` is unrestricted and no rate limiter was
  identified for login, registration, OTP, or sentiment endpoints.
- The Nominatim and OSRM public services are rate-limited external dependencies;
  repository documentation recognizes per-process scheduling and demo-service
  limits. Multi-instance policy compliance and provider availability are not
  verified.
- Sentiment inference uses a configured API key and bounded fetch timeouts;
  the external service was not contacted.
- Dependency installation reported npm advisories (11 moderate, 5 high, 1
  critical). Individual findings were not reviewed and no automated fix was
  applied; review the advisories in an approved environment.

## Findings

- **Fixed:** legacy custom JWT authentication removed in favor of verified
  Firebase identity; OTP serialization in shared responses;
  broad contact/student-ID fields in selected general profile/ride responses.
- **Open high:** OTP is not required to start a ride; verified-email workflow
  still needs Firebase/database/device E2E validation; complete cross-user
  authorization remains unverified.
- **Open medium:** OTP retry/reuse controls are absent; CORS is permissive; sensitive endpoints have no
  identified rate limiter.

See `BUG_REPORT.md` for reproduction details, impact, and required follow-up.

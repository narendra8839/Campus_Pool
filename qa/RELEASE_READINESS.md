# CampusPool Release Readiness

## Decision

**Not ready for closed student beta or wider campus rollout.** Static checks and
local automated suites pass, but production safety and persistence workflows
were not exercised, and high-priority ride safety, identity verification, and
concurrency risks remain.

## Internal developer testing

**Conditionally ready for local developer testing**, provided developers use a
dedicated non-production database, configure the Firebase project/Admin
credentials, and configure the matching Firebase client app.

Before connecting an environment:

1. Provision or identify an isolated test database/API deployment.
2. Confirm the database endpoint is non-production and contains no real
   student data.
3. Configure `FIREBASE_PROJECT_ID` and secure Admin credentials for that
   environment; never commit a service-account key.
4. Apply the additive Prisma schema only to that confirmed test database.
5. Use verified `@vit.edu` test accounts and synthetic ride data.

## Closed student beta

**Not ready.** Required conditions:

1. Verify Firebase email-link delivery and verified-claim enforcement end to
   end with the configured VIT project and isolated database.
2. Require successful OTP verification before starting a ride; define expiry,
   attempt limits, consumption, and retry behavior.
3. Make seat allocation safe under concurrent booking approvals and verify it
   using real PostgreSQL concurrency tests.
4. Run two-account authorization/data-isolation tests, including profiles,
   ride details, booking requests, cancellations, and ride status changes.
5. Run realistic passenger and biker journeys on supported devices with
   location permission denial, provider failure, network interruption, and
   app restart cases.
6. Resolve privacy policy for emergency/contact data and document location
   retention/sharing.
7. Verify push-notification expectations; the current activity feed is derived
   from ride/booking APIs and is not push delivery.

## Wider campus rollout

**Not ready.** In addition to all beta conditions:

- Use production-grade, monitored routing/geocoding services or document
  approved public-service usage limits and scaling behavior.
- Add reviewed rate limits for authentication and other sensitive endpoints;
  constrain CORS to approved origins.
- Complete performance, accessibility, and reliability testing under expected
  campus load.
- Run an approved dependency vulnerability review and operational security
  review.
- Establish monitoring, incident handling, support, data retention, and
  recovery procedures.
- Complete a full API/database test matrix and repeat release verification
  against a clean isolated release candidate.

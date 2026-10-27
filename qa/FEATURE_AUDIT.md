# CampusPool Feature Audit

Status definitions: PASS = behavior verified by a meaningful runnable test;
PARTIAL = source/tests cover part of the behavior but the full workflow is
unverified; FAIL = an executed test demonstrated a defect; BLOCKED = requires
unavailable safe environment or external dependency; NOT IMPLEMENTED =
confirmed absent from current code.

| Feature | Frontend | Backend | Database | Integration | Status | Evidence |
|---|---|---|---|---|---|---|
| Authentication/session | Firebase email/password login, verified-link signup, resend, reset, session gate | Firebase ID-token validation and verified profile provisioning | Nullable unique `firebaseUid`; nullable password; schema push pending | Unit tests cover claims/provisioning; real Firebase sign-in/API persistence not tested | PARTIAL | `lib/services/auth_service.dart`, `backend/src/controllers/authController.js`, `backend/test/firebaseProfile.test.js` |
| Student email verification | Signup link and login gate require a verified exact `@vit.edu` address | Firebase token claim and domain checked before profile creation/protected access | `isVerified` set after verified claim; schema push pending | Firebase config, delivery, and device/API E2E not verified | PARTIAL | `backend/src/utils/firebaseIdentity.js`, auth screens, `backend/src/middleware/authMiddleware.js` |
| Profile and vehicle | Profile/edit screens and service calls | Self-profile and vehicle update endpoints | User and vehicle fields | Persistence and validation not tested with a database | PARTIAL | `userController.js`, `auth_service.dart` |
| Student schedules | Schedule service/screens | Get/update schedule endpoints with transaction | `StudentSchedule` model | Database behavior not exercised | PARTIAL | `userController.js`; schema validation passes |
| Map and location | MapLibre map, place picker, route preview | Nominatim and OSRM proxy routes | Corridor/hub route data | Mocks/unit tests only; device permissions and provider service blocked | PARTIAL | Map screen, geocoding/routing tests |
| Ride creation/pricing | Offer ride form and OSRM preview | Validates ride and calculates full-route fare | Ride, corridor/hub links, waypoints | Database write and app-to-server workflow blocked | PARTIAL | `rideController.js`, `ridePricingService.js`; pricing tests pass |
| Ride search/matching | Search/filter and ride cards | Filters scheduled rides and ranks results | Ride indexes and relations | Search queries not run against an isolated database | PARTIAL | `rideController.js`, `ncfService.js` |
| Seeker segment fare | Selected route points and live fare estimate | Recalculates OSRM distance between seeker pickup/drop-off | Stores fare on booking | Service test and Flutter fare test pass; DB write blocked | PARTIAL | `ride_details_screen.dart`, `bookingController.js`, `ridePricing.test.js`, `ride_fare_test.dart` |
| Booking and capacity | Request, driver queue, passenger history | Conditional atomic seat decrement and booking transition in one transaction | Booking and Ride relations | Concurrent in-memory regression passes; PostgreSQL verification blocked | PARTIAL | `bookingApprovalService.js`, `bookingApproval.test.js`, `bookingController.js` |
| Ride lifecycle | Driver controls for scheduled/ongoing/completed states | Transition guard and associated booking updates | Ride/Booking status strings | Transition policy unit-tested; transactional workflow blocked | PARTIAL | `rideLifecycle.js`, `rideLifecycle.test.js` |
| Boarding OTP | Passenger displays accepted booking OTP; driver can submit | Generates and verifies OTP | `verificationOtp` field | No OTP delivery, consumption, retry-limit, or start-gating E2E test | PARTIAL | `bookingController.js`, `booking_model.dart`; open finding in `SECURITY_AUDIT.md` |
| Auto groups | Browse/create/join screens | Listing, requests, matching, membership | AutoGroup, AutoRequest, membership models | Deterministic matching/listing tests pass; database workflows blocked | PARTIAL | `autoGroupListingController.js`, `autoGroupMatching.test.js`, `autoGroupListing.test.js` |
| Reviews/ratings | Review and review history screens | Authenticated review creation, aggregation, sentiment endpoint | Unique ride/reviewer/reviewee constraint | Completion guard regression passes; persistence/external ML blocked | PARTIAL | `reviewController.js`, `authProfileRating.test.js`, `reviewSentiment.test.js` |
| Activity/alerts | Activity feed assembled from ride/booking APIs | No separate push notification API/provider | No notification model | Derived activity feed only; push/offline delivery absent | PARTIAL | `alert_service.dart`; no push implementation found |
| Dashboard/history | Dashboard, offered rides and bookings screens | Ride and booking list endpoints | Ride/Booking data | Counts/persistence not compared with a test DB | PARTIAL | `home_dashboard_screen.dart`, `my_rides_screen.dart` |
| Payments | Fare/contribution display only | No payment endpoint/provider | No payment model | No payment processing | NOT IMPLEMENTED | Backend route catalogue and Prisma schema |
| Admin/moderation | No admin screen found | No admin routes/role authorization found | No admin model | No moderation workflow | NOT IMPLEMENTED | Frontend screens and backend route inventory |

No feature above is marked PASS end-to-end: no isolated database, API server
test deployment, or mobile device was available for that level of verification.

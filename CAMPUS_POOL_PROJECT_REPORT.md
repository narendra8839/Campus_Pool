# Campus Pool — Project Report

## 1. Project overview

Campus Pool is a student ride-sharing application for coordinating bike and
scooty rides along shared college commute routes. A student can use the app as a
passenger looking for a lift, as a driver offering available seats, or both.
The project also includes a separate feature for coordinating groups of
students who want to share an auto.

The repository contains three main parts:

1. **Mobile and cross-platform client** — a Flutter application in `lib/`.
2. **REST API and persistence layer** — an Express.js API using Prisma and
   PostgreSQL in `backend/`.
3. **Offline data and machine-learning utilities** — route seeding, synthetic
   datasets, ride-match scoring, and optional review-sentiment training and
   inference in `backend/scripts/` and `backend/ml/`.

The application is built around a VIT commute-route catalogue for Pune, with
two corridors that meet at the college. Route-linked rides can be selected by
corridor hubs, while the map and general ride-routing features use road-route
geometry from external mapping services.

## 2. Implemented user capabilities

### Accounts and sessions

- Students can register and log in with email and password.
- The API issues JWTs; the Flutter client stores the token and a cached user
  profile locally.
- On launch, the client restores the session and opens the authenticated
  navigation shell when a saved user session is available.
- Authenticated API requests include the saved token. When the API reports an
  expired or unauthorized session, the client clears the session and returns
  the user to login.
- Profile data includes student details, rider/driver roles, vehicle
  information, emergency-contact fields, and rating statistics.

### Offering and discovering rides

- Drivers can offer a future ride with an origin, destination, departure time,
  seat capacity, supported vehicle type, helmet availability, and optional
  notes.
- The current supported vehicles for new rides are **bike** and **scooty**.
- Route-linked offers can be selected from a corridor and its ordered hubs.
  The offer screen provides commute-direction defaults and previews a driving
  route and fare when route coordinates are available.
- Passengers can search rides by origin, destination, date, requested seats,
  vehicle type, and corridor. Search results can be sorted by best match,
  earliest departure, lowest price, or driver rating.
- Ride details and ride lists are available from the client. The My Rides
  screen separates the user's offered rides from passenger bookings and
  supports active/past filtering.
- Drivers can review incoming booking requests and accept or reject them.
  Passengers and drivers can cancel bookings; drivers can update ride status
  and cancel offered rides.
- Booking requests contain pickup/drop locations, requested seat count, and an
  optional passenger note. The booking API also has an OTP verification
  endpoint.

### Route-aware ride pricing

- The backend calculates the ride contribution rather than trusting a fare
  submitted by the client.
- The configured fare is **₹5 per kilometre per passenger seat**.
- For valid endpoint coordinates, the backend requests OSRM driving distance,
  calculates the per-seat contribution from road distance, and stores the
  returned route geometry as ride waypoints.
- If OSRM cannot route valid coordinates, ride creation reports a routing
  error rather than silently substituting a straight-line fare.
- When coordinates are unavailable, the existing waypoint/straight-line
  distance calculation is retained.
- A booking fare is based on the ride's per-seat fare and the number of seats
  requested.

### Maps, place search, and corridors

- The Flutter client uses MapLibre with the public OpenFreeMap Liberty style.
- Users can explicitly search for places, select a result, tap the map for a
  location (reverse geocoding), and request a road route between selected
  places.
- The map displays route geometry, distance, and estimated duration. Route
  previews from an offered ride can also be shown on the Home map.
- The backend normalizes Nominatim results into a stable application response,
  and proxies OSRM driving directions to the client.
- The route catalogue stores corridors, ordered hubs, and road geometry.
  Seeded corridors are derived from the corridor text files and hub-order
  workbooks in the repository; the data is checked in so runtime seeding does
  not need to parse Excel files.
- Map and place-search screens display OpenStreetMap contributor attribution.

### Student-to-student auto groups

- Students can submit an auto-group request with pickup area, destination, and
  desired departure time.
- The backend matches requests with the same normalized pickup and destination
  within a 15-minute departure window.
- A group can contain up to four members and is considered ready at three
  members. Members can view their groups, confirm attendance, or leave.
- This feature coordinates students only. It does **not** find an auto driver,
  book a vehicle, calculate fares, or process payments.

### Reviews, ratings, and sentiment

- A student can submit a 1–5 star review with optional written feedback for a
  rider or driver associated with a ride.
- The API checks that the reviewer and reviewee participated in the ride
  through an accepted or completed booking, prevents self-reviews, and limits
  duplicate reviews for the same ride and people.
- User rating averages and counts are recalculated when a review is created.
- The Flutter client includes a review form and a review-history screen.
- Written comments can optionally be analyzed by a fine-tuned DistilBERT
  sentiment classifier. Sentiment is an informational suggestion: it does not
  change the star rating or block review submission.
- Sentiment training data can come from generated synthetic examples or an
  approved database export containing review ratings and comments. The export
  omits user identifiers. Synthetic-data metrics are not a measure of model
  performance on genuine student feedback.

### Activity, profile, and schedules

- The five-tab authenticated shell provides **Home**, **Rides**, **Offer**,
  **Map**, and **Profile** destinations.
- The Home dashboard displays the user's name, active-ride information, nearby
  rides, and map/route content backed by the API.
- The in-app Activity screen builds booking and ride updates from existing
  API data. It supports refresh and marking items read in the current screen
  state; it is not a push-notification delivery system.
- Students can view and edit profile data, vehicle details, and emergency
  contact fields, and can log out.
- A per-user weekly student-schedule API and data model are implemented.
  Synthetic users also receive generated schedules. The current Flutter
  screens do not include a dedicated timetable editor or timetable-upload
  workflow.

## 3. Application architecture

### Flutter client

The Flutter application is organized into:

- `lib/screens/` — authentication, dashboard, ride search/details/offer,
  personal rides, driver request queue, map, profile, activity, auto groups,
  and reviews.
- `lib/services/` — HTTP access and feature-specific services for accounts,
  rides, bookings, routes, geocoding, routing, schedules, reviews, activity,
  and route previews.
- `lib/models/` — typed models for users, rides, bookings, reviews, corridors,
  hubs, routes, places, schedules, and activity.
- `lib/components/` and `lib/theme/` — shared UI components, colors, spacing,
  typography, and Material theme.
- `lib/routes/` — named navigation routes and protected-route return handling.

The main shell uses an `IndexedStack` so tab state is retained while switching
between the core destinations. The project dependencies include Flutter,
`http`, `shared_preferences`, MapLibre, Google Fonts, and UI helper packages.

The API client can be configured at build time with the `API_BASE_URL`
`--dart-define`. If it is not supplied, the client tries configured deployed
and local development URLs. For local-device development, choose a reachable
backend URL rather than relying on a workstation-specific fallback address.

### Backend

The API is an Express application with JSON request handling, Helmet security
headers, CORS, development request logging, health/API information endpoints,
route modules, and centralized 404/error middleware. Controllers implement the
feature logic; Prisma provides access to PostgreSQL (including Neon-hosted
PostgreSQL deployments).

At startup, the server attempts to connect to the database and retries
transient connection failures up to three times. It exposes `GET /health` and
`GET /api` for health and endpoint discovery.

### Persistence model

The Prisma schema defines these primary entities:

| Entity | Purpose |
| --- | --- |
| `User` | Student identity, roles, vehicle and emergency-contact details, and rating aggregates |
| `Ride` | Driver, endpoints, departure, capacity, vehicle, fare contribution, status, and waypoints |
| `Booking` | Passenger request, pickup/drop, seats, status, fare, notes, and boarding OTP |
| `Review` | Ride-linked reviewer/reviewee rating and comment, unique per ride/reviewer/reviewee |
| `Corridor` | Named commute route and its stored route geometry |
| `Hub` | Named, normalized route stop with optional coordinates |
| `CorridorHub` | Ordered association between a corridor and its hubs |
| `AutoRequest` | A student's normalized pickup/destination/time request for an auto group |
| `AutoGroup` | A matched group with readiness and membership state |
| `AutoGroupMember` | Membership, confirmation, and request linkage |
| `StudentSchedule` | One user's recurring schedule entry per day of week |

Ride, booking, review, group, and schedule records use relational links and
indexes for common lookups. Deletion behavior is defined in the Prisma
relations (for example, dependent bookings are removed with a ride).

## 4. Backend API inventory

All endpoints below are mounted under `/api` unless shown otherwise. The
current route middleware determines which require a JWT; the client should
include the JWT in the authorization header for authenticated routes.

| Area | Routes | Main operations |
| --- | --- | --- |
| Health and API info | `GET /health`, `GET /api` | Service health and endpoint discovery |
| Authentication | `POST /auth/register`, `POST /auth/login`, `GET /auth/me` | Register, log in, fetch current user |
| Users | `GET /users/:id`, `PUT /users/profile`, `PUT /users/vehicle`, `GET /users/me/schedule`, `PUT /users/me/schedule` | Profile, vehicle, and weekly schedule |
| Rides | `GET /rides`, `POST /rides`, `GET /rides/:id`, `GET /rides/my-rides`, `PATCH /rides/:id/status`, `DELETE /rides/:id` | Search, offer, inspect, manage, and cancel rides |
| Bookings | `POST /bookings`, `GET /bookings/my-bookings`, `GET /bookings/driver-requests`, `GET /bookings/ride/:rideId`, `PATCH /bookings/:id/respond`, `PATCH /bookings/:id/cancel`, `POST /bookings/:id/verify-otp` | Request and manage lift bookings |
| Reviews | `POST /reviews`, `GET /reviews/user/:userId`, `POST /reviews/sentiment` | Submit/read reviews and optionally classify comment sentiment |
| Auto groups | `POST /auto-groups/requests`, `GET /auto-groups/my-groups`, `GET /auto-groups/:id`, `PATCH /auto-groups/:id/confirm`, `PATCH /auto-groups/:id/leave` | Create and manage student groups |
| Route catalogue | `GET /routes/corridors`, `GET /routes/corridors/:id` | Read corridors and ordered hubs |
| Geocoding | `GET /geocoding/search`, `GET /geocoding/reverse` | Search places and reverse-geocode coordinates |
| Routing | `GET /routing/route` | Request driving geometry, distance, and duration |

Search and route parameters are validated by their respective controllers.
Nominatim requests are submitted explicitly rather than on every keystroke.
The geocoding and routing integrations cache results and rate-limit outbound
requests within a backend process; those controls are not shared across
multiple deployed instances.

## 5. Matching and machine-learning work

### Ride-match acceptance scoring

The offline Neural Collaborative Filtering (NCF) prototype trains from
booking interactions. Accepted/completed bookings are positive interactions;
rejected bookings are negative; pending/cancelled bookings are excluded. When
PyTorch is available, the trainer can fit the model. Without it, it writes a
deterministic popularity baseline so data preparation remains usable.

The backend reads an optional generated prediction lookup and attaches
`matchAcceptanceProbability` to authenticated ride-search results. When a
rider/driver pair is not in the lookup, a rating/acceptance-history fallback
score is used. A score is used for ranking and does not prevent a passenger
from requesting a ride.

### Review sentiment service

Sentiment training fine-tunes
`distilbert/distilbert-base-uncased` to classify comments as negative, neutral,
or positive based on their associated star ratings: 1–2, 3, and 4–5 stars,
respectively. Training validates input, normalizes and deduplicates text,
excludes duplicate text with conflicting sentiment labels, requires at least
ten unique unambiguous comments per class, and uses a deterministic stratified
holdout split.

The optional Python FastAPI inference service runs separately from Express.
The Express endpoint forwards authenticated requests to it and returns an
explicit unavailable response if inference cannot be completed. Reviews can
still be submitted when sentiment analysis is unavailable.

## 6. Development data and supporting scripts

- `backend/data/routes.json` is the normalized route catalogue used by seeding
  and synthetic data generation.
- `npm run seed:routes` seeds corridors, hubs, road geometry, and deterministic
  development records after the Prisma schema has been applied.
- `npm run generate:synthetic` creates deterministic JSON and CSV development
  data. The generator is configured for 500 users, 1,000 rides, 3,000
  bookings, up to 900 reviews, and 600 auto requests.
- `npm run import:synthetic` imports that dataset into the configured
  database; its intended use is development/test data, not production
  accounts.
- `npm run export:reviews:sentiment` exports only review rating and comment
  fields for optional sentiment training.
- `npm run recalculate:fares` recalculates stored fares, and
  `npm run cleanup:four-wheelers` removes older four-wheeler ride records and
  resets related vehicle details to align with supported ride types.

Generated model artifacts and local review-export data are kept out of source
control according to the ML workflow's ignore rules.

## 7. Local setup and run commands

### Requirements

- Flutter SDK compatible with the constraint in `pubspec.yaml`.
- Node.js 18 or newer for the backend.
- A PostgreSQL database and connection URLs for Prisma.
- Python is only needed for optional ML workflows. Sentiment inference also
  requires its trained model artifact and the Python packages listed in
  `backend/ml/requirements-ml.txt`.

### Backend

From the repository root:

```powershell
Set-Location backend
npm install
Copy-Item .env.example .env
```

Edit `backend/.env` with a real database connection, a newly generated
application JWT secret, and appropriate external-service settings. Do not use
example credentials as deployment secrets. Then apply the schema and start the
API:

```powershell
npx prisma db push
npm run seed:routes
npm run dev
```

The route seed is optional for general API startup, but corridor-based ride
selection and route map content require corridor data to have been seeded.

### Flutter client

From the repository root:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api
```

Use a backend URL reachable from the target platform. Android emulators and
physical devices may need a different host address than desktop development.

### Optional ML services

From `backend/`, train sentiment using synthetic comments or an approved
review export:

```powershell
npm run generate:synthetic
python -m pip install -r ml/requirements-ml.txt
npm run train:sentiment -- --data data/synthetic/reviews.csv
npm run serve:sentiment
```

Set `SENTIMENT_SERVICE_URL` in the backend environment to the running local
service when it is not using the default address. The optional NCF artifacts
can be generated with `npm run train:ncf`.

## 8. Verification

Flutter tests are in the root `test/` directory and cover models, fare
calculation, route/geocoding parsing, profile behavior, navigation, and review
sentiment UI behavior. Run them from the repository root:

```powershell
flutter test
flutter analyze
```

Backend tests use Node's built-in test runner and cover geocoding, route
calculation, ride pricing, sentiment request handling, and synthetic review
generation. Run them from `backend/`:

```powershell
node --test
```

The backend also exposes individual scripts for geocoding, routing, and fare
tests (`npm run test:geocoding`, `npm run test:routing`, and
`npm run test:pricing`).

## 9. Scope boundaries and operational considerations

- This is a student ride-coordination application; the auto-group feature is
  not an auto-booking or payment product.
- There is no in-app safety-reporting or blocked-user workflow represented in
  the current API route set. Emergency-contact fields are profile data and
  should not be treated as an emergency-response service.
- The activity feed is assembled from API state; push notifications are not
  part of the implementation described here.
- Student schedules are persisted and generated for development data, but a
  user-facing schedule-management screen and timetable import flow are not
  present in the current screen set.
- Public Nominatim and OSRM endpoints have usage limits and no production
  availability guarantee. The in-memory rate limits and caches are per
  process, so multi-instance deployments need shared controls or suitable
  hosted providers.
- Map tiles and geocoding/routing depend on network access. Their external
  usage policies and attribution requirements apply.
- A sentiment result is optional guidance, not moderation, a safety decision,
  or evidence of review truthfulness. Model quality depends on suitable real
  evaluation data; synthetic training results must not be presented as
  production accuracy.
- Before a production release, deployment-specific review is still needed for
  secrets, CORS policy, database migration strategy, privacy/retention, abuse
  controls, monitoring, and platform signing/configuration.

## 10. Repository areas

| Path | Contents |
| --- | --- |
| `lib/` | Flutter screens, services, models, components, routing, and theme |
| `backend/src/` | Express app, route handlers, middleware, and integrations |
| `backend/prisma/schema.prisma` | PostgreSQL data model |
| `backend/data/` | Route catalogue and generated development datasets |
| `backend/scripts/` | Seeding, import/export, fare, and data-maintenance utilities |
| `backend/ml/` | NCF and sentiment training/inference utilities |
| `test/` | Flutter unit and widget tests |
| `backend/test/` | Backend unit tests |
| `Corridor_1.txt`, `Corridor_2.txt`, and root workbooks | Source material for commute corridors and hub ordering |

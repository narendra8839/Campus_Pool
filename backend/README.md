# 🚗 Campus Pool Backend API (Neon PostgreSQL + Express + Prisma)

A Node.js and Express.js REST API backend for the **Campus Pool** college ride-sharing application, powered by **Neon Serverless PostgreSQL** and **Prisma ORM**.

---

## 📁 Project Structure

```
backend/
├── prisma/
│   └── schema.prisma             # PostgreSQL schema (Users, Rides, Bookings, Reviews)
├── src/
│   ├── config/
│   │   └── prisma.js             # Singleton Prisma client instance
│   ├── controllers/
│   │   ├── authController.js      # Student register, login, current user
│   │   ├── userController.js      # Profile, vehicle details, emergency contacts
│   │   ├── rideController.js      # Offer rides, search, filter, status updates
│   │   ├── bookingController.js   # Lift requests, accept/reject, cancellations
│   │   └── reviewController.js    # Star ratings & user reviews
│   ├── middleware/
│   │   ├── authMiddleware.js      # JWT authentication guard
│   │   └── errorMiddleware.js     # 404 & centralized error handler (handles Prisma codes)
│   ├── routes/
│   │   ├── authRoutes.js          # /api/auth
│   │   ├── userRoutes.js          # /api/users
│   │   ├── rideRoutes.js          # /api/rides
│   │   ├── bookingRoutes.js       # /api/bookings
│   │   └── reviewRoutes.js        # /api/reviews
│   ├── utils/
│   │   └── generateToken.js       # JWT signing utility
│   ├── app.js                     # Express app setup & middleware stack
│   └── server.js                  # Entry point listener
├── .env.example                   # Environment configuration template
├── .env                           # Local environment file
├── .gitignore
├── package.json
└── README.md
```

---

## 🌐 Environment Configuration

We provide environment-specific template files for different deployment stages:

| Environment | Template File | Description |
|-------------|---------------|-------------|
| Development | `.env.dev.template` | For local development |
| Staging     | `.env.staging.template` | For staging server |
| Production  | `.env.prod.template` | For production server |

### Usage

1. Copy the appropriate template to `.env`:
   ```bash
   # For development
   cp .env.dev.template .env

   # For staging
   cp .env.staging.template .env

   # For production
   cp .env.prod.template .env
   ```

2. Fill in the actual values for your environment.

### Important Notes

- **Never commit `.env` files** to version control. They are already ignored by `.gitignore`.
- Use environment-specific secrets and configurations.
- Consider using a secrets manager or environment variables provided by your hosting platform for staging and production.
- Set `NOMINATIM_USER_AGENT` to identify CampusPool and provide a monitored contact address when using public Nominatim.

---

## 🛠️ Quick Start & Setup

### 1. Prerequisites
- **Node.js**: `v18+` or `v20+`
- **Neon PostgreSQL Account**: Free database at [neon.tech](https://neon.tech)

### 2. Install Dependencies
```bash
cd backend
npm install
```

### 3. Configure Neon Database Connection
In `backend/.env`, set your `DATABASE_URL` from your Neon console:
```env
PORT=5000
NODE_ENV=development
DATABASE_URL="postgresql://neondb_owner:YOUR_PASSWORD@ep-xyz.us-east-2.aws.neon.tech/neondb?sslmode=require"
JWT_SECRET=campus_pool_jwt_super_secret_key_2026
JWT_EXPIRES_IN=30d
ALLOWED_EMAIL_DOMAIN=
NOMINATIM_USER_AGENT="CampusPool/1.0 (contact: your-email@example.com)"
```

If Neon closes an idle pooled connection, restart the backend; startup retries
the database connection up to three times before failing clearly. For local
development, use Neon's pooled connection URL and keep the connection limit
small, for example by adding `&connection_limit=5&pool_timeout=20` to the
`DATABASE_URL` query string.

### 4. Push Database Schema to Neon
Sync your PostgreSQL database tables with the schema:
```bash
npx prisma db push
```

*(Optional)* Open the visual database inspector:
```bash
npm run prisma:studio
```

### 5. Run Development Server
```bash
npm run dev
```

### Route catalogue and deterministic demo data

The normalized route catalogue in `data/routes.json` is derived from
`Corridor_1.txt`, `Corridor_2.txt`, and the hub-order workbook at the
repository root. It is intentionally checked in so runtime seeding does not
depend on an Excel parser. The catalogue models two directional VIT commute
corridors:

- Swargate -> shared Market Yard/Bibwewadi section -> VIT College
- Katraj -> shared Market Yard/Bibwewadi section -> VIT College

After `prisma db push`, run:

```bash
npm run seed:routes
```

The route seed also imports the generated road LineString geometry from
`Corridor_1.txt` and `Corridor_2.txt` into each corridor's `routeData`.
Flutter renders that geometry as MapLibre polylines; it does not connect hubs
with straight lines.

The seed is deterministic and safe to rerun. It creates corridors, ordered
corridor hubs, VIT users, morning/evening rides, a booking, review, and an
auto-group. Seed accounts use `user1@seed.campus.pool` through
`user8@seed.campus.pool` and password `CampusPool123!`. Route clients can
read `GET /api/routes/corridors`; route-linked rides accept `corridorId`,
`originHubId`, and `destinationHubId` while retaining the existing location
fields.

### Place search and reverse geocoding

CampusPool proxies geocoding requests through its backend:

```text
GET /api/geocoding/search?q=Kothrud&limit=5
GET /api/geocoding/reverse?lat=18.5&lon=73.8
```

The backend calls the public Nominatim service, returns a stable CampusPool
place shape, caches results in memory for five minutes, and schedules outbound
requests at no more than one per second. Search queries must contain 3–200
characters; result limits are capped at 10. Search is submitted explicitly,
not sent as-you-type, in line with the public Nominatim usage policy. Requests
time out explicitly, and the backend bounds its outbound queue.

Configure `NOMINATIM_USER_AGENT` in each deployment with the application name
and a monitored contact address. The Flutter map submits place searches
explicitly and reverse-geocodes map taps. The UI displays OpenStreetMap
contributor attribution. Caching and request scheduling are process-local; a
multi-instance deployment needs a shared cache and rate limiter to enforce the
policy across instances. Public Nominatim is subject to its
[usage policy](https://operations.osmfoundation.org/policies/nominatim/); for
sustained production traffic, use a compliant hosted service or operate your
own instance.

### Driving routes

The backend proxies driving directions through OSRM:

```text
GET /api/routing/route?originLat=18.5&originLon=73.8&destinationLat=18.46&destinationLon=73.86
```

Responses include road-route GeoJSON coordinates in `[longitude, latitude]`
order, distance in metres, and duration in seconds. The Campus Map can route
between two selected places and displays the returned route, distance, and
estimated duration. The endpoint validates coordinates and reports no-route,
timeout, and provider errors explicitly. Identical requests are cached briefly
and outbound requests are scheduled at most once per second per backend process.

`OSRM_BASE_URL` can point at a compatible OSRM service. The default public
`router.project-osrm.org` server is for reasonable, low-volume use and has no
service guarantee; configure a hosted or self-managed OSRM instance for
production traffic. Process-local caching and scheduling do not coordinate
multiple deployed instances.

Only bikes and scooties can be offered. If an older database contains
four-wheeler records, remove those rides and reset the associated vehicle
details with:

```bash
npm run cleanup:four-wheelers
```

Fare is calculated by the backend at **₹5 per kilometre per passenger seat**.
For rides with valid endpoint coordinates, the backend uses OSRM's driving
distance and stores the returned road geometry as ride waypoints; a routing
provider error prevents the ride from being created rather than silently
quoting a straight-line fare. When coordinates are unavailable, the backend
retains the legacy waypoint/straight-line estimate. A booking's total is the
per-seat route fare multiplied by the number of requested seats; client
submitted contribution values are ignored. The Offer Ride form previews the
road distance and per-seat fare, and the selected route is drawn on the Home
map.

To generate larger deterministic JSON and CSV datasets for analysis or bulk
loading, run:

```bash
npm run generate:synthetic
```

### Match acceptance NCF prototype

Train the offline neural collaborative filtering prototype with:

```bash
npm run train:ncf
```

The trainer uses `ACCEPTED` and `COMPLETED` bookings as positive interactions,
`REJECTED` bookings as negative interactions, and excludes `PENDING` and
`CANCELLED` bookings. It writes ignored artifacts under
`backend/ml/model-output/`, including evaluation metadata and a JSON prediction
lookup used by ride search. Install the optional dependencies in
`backend/ml/requirements-ml.txt` to train the PyTorch model.

Authenticated `GET /api/rides` responses include
`matchAcceptanceProbability` for each ride. The Flutter find-rides screen
offers a **Best Match** sort option. Unknown rider-driver pairs use a
rating-based fallback and are never blocked from booking.

The output is written to `backend/data/synthetic/`. It contains 500 users,
1,000 VIT commute rides, 3,000 valid route-segment bookings, reviews, and
auto-group requests. The generator uses the corridor hub sequence to ensure
morning rides end at VIT, evening rides start at VIT, and every booking stays
within its ride segment.

#### Route API shapes

`GET /api/routes/corridors` returns:

```json
{
  "success": true,
  "count": 1,
  "data": [{
    "id": "corridor-id",
    "name": "Corridor 1",
    "originName": "Swargate",
    "destinationName": "VIT College",
    "hubs": [{
      "id": "corridor-hub-id",
      "corridorId": "corridor-id",
      "hubId": "hub-id",
      "sequence": 0,
      "hub": {
        "id": "hub-id",
        "name": "VIT College",
        "normalizedName": "vit campus",
        "latitude": 18.5456,
        "longitude": 73.8567
      }
    }]
  }]
}
```

`GET /api/routes/corridors/:id` returns `{ "success": true, "data": <corridor> }`
with the same corridor shape. Route-linked ride responses retain all existing
ride fields and add `corridor`, `originHub`, and `destinationHub`; each hub
has `id`, `name`, `normalizedName`, `latitude`, and `longitude`.

When creating a route-linked ride, send the existing ride payload plus:

```json
{
  "corridorId": "corridor-id",
  "originHubId": "hub-id",
  "destinationHubId": "hub-id"
}
```

### Synthetic route-aware data

Generate an inspection-ready development dataset without writing to the
database:

```bash
npm run generate:synthetic
```

The deterministic generator uses the normalized route catalogue and creates
500 users, 1,000 rides, 3,000 bookings, 900 reviews, and 600 auto requests
across a rolling 90-day window centered on September 21, 2026. It writes JSON and CSV files to
`backend/data/synthetic/`, including a manifest, route catalogue, and
relationship-linked entity files. Reviews are generated only for unique valid
booking relationships, so the actual review count can be lower than the
configured maximum of 900. The fixed synthetic account password is documented
in the manifest and must not be reused outside test data. Synthetic rides and
bookings model the campus commute only: each record is either `hub -> VIT
College` or `VIT College -> hub`; intermediate hub-to-hub bookings are not
generated. Each synthetic user also receives a Monday-Saturday recurring

To apply the generated dataset to the configured PostgreSQL database:

```bash
npx prisma db push
npm run import:synthetic
```

The import is repeatable: it replaces only prior synthetic/seed accounts and
their dependent records, preserving unrelated real accounts and rides. Seed
login accounts use emails `synthetic0001@synthetic.campus.pool` through
`synthetic0500@synthetic.campus.pool` and password `CampusPool123!`. Each synthetic user also receives a Monday-Saturday recurring
schedule with no-class days, a class window between 8:00 AM and 6:00 PM, and
sessions lasting approximately 3-4 hours. Ride departure times are derived
from that schedule: 30 minutes before class for travel to college and 15
minutes after class for the return trip. The generated
`student-schedules.json/csv` files are the planned input shape for future
timetable uploads.

Morning rides (before noon) must move from a lower corridor sequence toward
VIT; evening rides must move from VIT toward a lower sequence. Bookings on
route-linked rides must use corridor hub names for `pickupName` and `dropName`
in the same direction.

---

## 📡 API Endpoints Reference

### 🔐 Authentication (`/api/auth`)
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/auth/register` | Register new student account | No |
| `POST` | `/api/auth/login` | Authenticate student and get JWT | No |
| `GET` | `/api/auth/me` | Get current logged-in user info | Yes (Bearer) |

#### Example Register Request:
```json
POST /api/auth/register
{
  "name": "Rahul Sharma",
  "email": "rahul.sharma@college.edu",
  "password": "Password@123",
  "phone": "+919876543210",
  "college": "Engineering College",
  "rollNumber": "CS202401",
  "gender": "male",
  "vehicle": {
    "type": "bike",
    "model": "Royal Enfield Classic 350",
    "plateNumber": "MH12AB1234",
    "helmetProvided": true,
    "totalSeats": 1
  }
}
```

---

### 👤 Users & Profile (`/api/users`)
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `GET` | `/api/users/:id` | View user profile, stats & reviews | Yes |
| `PUT` | `/api/users/profile` | Update profile (name, rollNo, contact) | Yes |
| `PUT` | `/api/users/vehicle` | Update vehicle info & seat capacity | Yes |

---

### 🛵 Rides (`/api/rides`)
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/rides` | Offer a new ride | Yes |
| `GET` | `/api/rides` | Search available rides (supports filters) | No |
| `GET` | `/api/rides/:id` | Get single ride details & passengers | Yes |
| `GET` | `/api/rides/my-rides`| List all rides offered by logged-in user | Yes |
| `PATCH` | `/api/rides/:id/status`| Update status (`ONGOING`, `COMPLETED`, `CANCELLED`) | Yes (Driver) |
| `DELETE` | `/api/rides/:id` | Cancel an offered ride | Yes (Driver) |

#### Search Query Parameters:
- `from`: Origin location keyword (e.g. `Kothrud`)
- `to`: Destination location keyword (e.g. `Campus Gate 2`)
- `date`: Departure date (`YYYY-MM-DD`)
- `vehicleType`: `bike`, `scooty`, `car`
- `seats`: Minimum required seats (default `1`)

---

### 🎟️ Lift Bookings (`/api/bookings`)
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/bookings` | Request a lift on a ride | Yes |
| `GET` | `/api/bookings/my-bookings` | Passenger's active & past bookings | Yes |
| `GET` | `/api/bookings/ride/:rideId` | Driver views booking requests for a ride | Yes (Driver) |
| `PATCH` | `/api/bookings/:id/respond` | Driver accepts/rejects request (`ACCEPTED` / `REJECTED`) | Yes (Driver) |
| `PATCH` | `/api/bookings/:id/cancel` | Cancel booking | Yes (Passenger/Driver) |

---

### ⭐ Reviews & Ratings (`/api/reviews`)
| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/reviews` | Post star rating (1-5) and feedback | Yes |
| `GET` | `/api/reviews/user/:userId` | Get all reviews received by a user | No |

---

### 🚕 Auto Groups (`/api/auto-groups`)

Version 1 coordinates students travelling from the same typed pickup area to the same typed destination within **15 minutes**. A group has up to four students and becomes ready at three members. It does **not** calculate fares, collect payments, or book an auto.

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/auto-groups/requests` | Create a request and join/create a compatible group | Yes |
| `GET` | `/api/auto-groups/my-groups` | View the current student's active groups | Yes |
| `GET` | `/api/auto-groups/:id` | View a group the current student belongs to | Yes |
| `PATCH` | `/api/auto-groups/:id/confirm` | Confirm attendance once the group is ready | Yes |
| `PATCH` | `/api/auto-groups/:id/leave` | Leave an auto group | Yes |

Example request:

```json
{
  "pickupName": "Viman Nagar",
  "destinationName": "College Main Gate",
  "desiredDepartureTime": "2026-09-02T03:30:00.000Z"
}
```

---

## 🧪 Health & Diagnostics
- **Health Check**: `GET http://localhost:5000/health`
- **API Overview**: `GET http://localhost:5000/api`

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
```

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

## 🧪 Health & Diagnostics
- **Health Check**: `GET http://localhost:5000/health`
- **API Overview**: `GET http://localhost:5000/api`

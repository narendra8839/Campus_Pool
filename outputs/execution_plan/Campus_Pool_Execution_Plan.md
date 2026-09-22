# 🏍️ Campus Pool — Detailed Execution Plan

> **App:** Ride-sharing for college students to take lifts from peers travelling the same route with bikes/vehicles.
> **Strategy:** Build a **testable prototype first**, then **update & refine** on top of it.
> **Companion file:** `Campus_Pool_Execution_Plan.csv` (same tasks, importable into Excel/Sheets).

---

## 📊 Current State of the Project

| Layer | Status |
|---|---|
| Backend (Express + Prisma + Neon PostgreSQL) | ✅ **Complete** — Auth, Users, Rides, Bookings, Reviews, Auto-Groups all coded |
| Flutter design system (theme, components) | ✅ Complete |
| Auth UI (login + register) | ✅ Complete (uses backend JWT) |
| Home dashboard | ⚠️ UI-only (mock data, no navigation wiring) |
| Auto-Groups screen | ✅ Built (talks to API) |
| Rides (find/offer/book), Profile, Vehicle, Reviews, Notifications | ❌ Not built yet |
| Firebase Auth | ⚠️ Initialized but unused (duplicate of JWT) |

---

## 🎯 Phase A — Build the Testable Prototype (Core "Happy Path")

**Milestone A:** A student can register/login → offer a ride OR search & book a ride → accept/decline → see it in "My Rides" — all end-to-end against the real backend.

| ID | Task | Priority | Acceptance Criteria |
|---|---|---|---|
| A1 | Verify backend runs & DB schema deployed (`prisma db push`, health check) | Critical | `GET /health` ok; all tables exist |
| A2 | Create dev/staging/prod env matrix & `.env` templates; remove committed secrets | Critical | No secrets in git |
| A3 | Remove Firebase vs JWT duplication — pick ONE auth (recommend Express JWT) | Critical | Single consistent login path |
| A4 | Move hard-coded API base URL (LAN IP) into build-time config | Critical | No source edits per device |
| A5 | Create `RideModel`/`BookingModel`/`ReviewModel` DTOs with safe JSON parsing | Critical | Unit-testable parsing |
| A6 | `RideService` (search, detail, offer, my-rides, status, cancel) | Critical | All `/api/rides` reachable |
| A7 | `BookingService` (request, list, driver-requests, respond, cancel) | Critical | All `/api/bookings` reachable |
| A8 | **Find Rides** screen with filters + loading/empty/error states | Critical | Live search returns API results |
| A9 | **Ride Details** screen + booking request form | Critical | Passenger inspects & submits request |
| A10 | **Offer Ride** form (capacity, route, time, vehicle, notes) | Critical | Driver creates validated ride |
| A11 | **My Rides** (driver view + passenger view) | Critical | Live offered & accepted bookings show |
| A12 | Driver **booking-request queue** with accept/reject | Critical | Seat count + status update visibly |
| A13 | Wire dashboard cards / active ride / nearby rides to real API | Critical | No hard-coded rides remain |
| A14 | Cancellation & status-change confirmation/error flows | High | No accidental cancel |
| A15 | **Prototype test pass** — full lifecycle on device/emulator | Critical | Whole flow passes on Android emulator + device |

✅ **Exit gate A:** End-to-end prototype works on Android emulator **and** a physical device against the live backend.

---

## 🎯 Phase B — Update & Refine (Harden, Complete, Polish)

**Milestone B:** Full app with all screens, safety controls, tests, and a releasable build.

| ID | Task | Priority | Acceptance Criteria |
|---|---|---|---|
| B1 | Replace bottom-nav toggle with real routes (Home, Rides, Offer, Alerts, Profile) | High | Each tab opens usable destination |
| B2 | Profile view + edit form (`/api/users/profile`) | High | Reads/updates with validation |
| B3 | Vehicle settings form for drivers | Medium | API + role restrictions |
| B4 | Token expiry / 401 handling, logout, login return path | Critical | Expired user returns to login safely |
| B5 | Post-ride review + review-history screens | Medium | One 1–5★ per ride, eligibility checked |
| B6 | In-app activity/booking-update (alerts) screen | Medium | Meaningful updates visible |
| B7 | Auto-Groups schema deploy + endpoint smoke tests | High | Create/join/confirm/leave verified |
| B8 | Auto-Groups 4-user matching/readiness/leave test | High | Edge cases documented |
| B9 | Auto-Groups empty/error/refresh/confirm state polish | Medium | States + "fare not handled" note |
| B10 | Community rules, reporting flow, blocked-user policy, emergency guidance | Critical | Approved policy + in-app reporting |
| B11 | Input validation + consistent error responses on all endpoints | Critical | Malformed → safe 4xx |
| B12 | CORS restriction, Helmet config, rate-limit auth | Critical | Production allow-list + abuse protection |
| B13 | Minimize exposed phone/contact data + retention policy | High | Minimal PII shown |
## ⚠️ Key Risks & Decisions (Resolve Early)

| ID | Type | Item | Recommendation |
|---|---|---|---|
| R1 | Decision | Auth source of truth (Firebase vs JWT) | Use Express JWT; remove Firebase to avoid duplicate |
| R2 | Risk | Device can't reach backend (hard-coded LAN IP) | Build-time config + env-based URLs |
| R3 | Risk | Seat overbooking under concurrency | Transaction-level seat protection (already partially there — add tests) |
| R4 | Decision | Safety operating model (reporting, verification) | Draft policy before beta |
| R5 | Risk | No automated tests | Add suites in Phase B |
| R6 | Risk | Auto-Groups schema not deployed | Deploy in B7 |

---

## 📁 Files Created in This Step

- `outputs/execution_plan/Campus_Pool_Execution_Plan.md` ← **this file**
- `outputs/execution_plan/Campus_Pool_Execution_Plan.csv` ← task list ready for Excel/Sheets import

> The CSV contains the same tasks with full columns:  
> `ID,Phase,Workstream,Task,Priority,Owner,Planned Start,Target End,Status,% Complete,Dependency,Acceptance Criteria,Next Action,Notes`  
> Open it in Excel or Google Sheets and apply styling/filters as desired.  
> (Later, if you want a styled `.xlsx` with conditional formatting like your existing `build_tracker.mjs`, I can generate it from this CSV using `exceljs` or `openpyxl`.)

---

## ✅ How to Use This Plan

1. **Review & Adjust** – Change owners, dates, or priorities as needed in the CSV or Markdown.
2. **Start Prototype (Phase A)** – Work top-to-bottom through A1→A15.
3. **Verify Exit Gate A** – End-to-end register/login/offer/search/book/accept cycle works on device.
4. **Proceed to Refine (Phase B)** – Complete B1→B25.
5. **Verify Exit Gate B** – App is tested, releasable, and launch-ready.

When a task is done, update its **Status** to `"Done"` and **% Complete** to `100`.  
Use the CSV to re-import into Excel and regenerate any dashboard views you like.

---

Let me know if you'd like:
- Estimated durations (in days) added to each task,
- A separate "Definition of Done" column,
- Or the CSV converted right now to a formatted `.xlsx` (just say the word).

The plan is ready for you to begin execution.
| B14 | Authorization audit (rides/bookings/reviews/profiles/groups) | Critical | Cross-user access denied in tests |
| B15 | Backend test DB + seed helpers + integration test runner | Critical | Isolated from prod DB |
| B16 | Backend coverage: auth/rides/bookings/reviews/groups/authorization | Critical | Happy + failure paths |
| B17 | Flutter service/model tests (HTTP failures, token, JSON) | High | Deterministic client logic |
| B18 | Flutter widget tests (auth, forms, states, navigation) | High | Screens render + validate |
| B19 | Device/browser test matrix + regression checklist | High | Platforms pass |
| B20 | Controlled student beta + feedback/funnel metrics | High | Beta exit criteria met |
| B21 | Deploy API + DB migration to staging → production | Critical | Health checks, rollback steps |
| B22 | Error logging, uptime checks, metrics dashboard | High | Alerted on failure |
| B23 | Android signing, package IDs, icons, privacy links | High | Releasable build installs |
| B24 | Update README (setup, env, commands, architecture, tests) | Medium | Clean-checkout run guide |
| B25 | Launch checklist, analytics, support contact, go/no-go | Critical | Signed-off launch |

✅ **Exit gate B:** Prototype hardened into a complete, tested, releasable app.
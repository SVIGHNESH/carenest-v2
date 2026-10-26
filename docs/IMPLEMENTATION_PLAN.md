# CareNest v2: Implementation Plan

Version 2, 2026-10-27.
Based on `flow-v2.md`, `wireframes-v2.html` (approved by the client with no changes on 2026-10-26), a read of the v1 code in `/home/vighnesh/Work/DRAPP-SYSTEM`, and the decisions from the grill session (section 2).
`flow-v2.md` says *what* the product does.
This plan says *how* we build it, *in what order*, and records every decision made since.
Where this plan and `flow-v2.md` disagree, this plan wins.

## 1. Summary

- New monorepo in this folder: `backend/`, `admin/`, `app/`, `docs/`.
- v1 code is the starting point, not the target: we keep what is good (OTP service, phone handling, design tokens) and rebuild the rest on a stricter stack.
- Full functional scope ships: user app, backend and admin panel together.
  Only monitoring and analytics wait until after launch.
- Nothing is live, so there is no backward compatibility, no data import, and a fresh database.
- Hosting: Railway Hobby, production plus a staging environment that sleeps when idle, about $5-8/month (about $9-11 if staging is kept awake).
- Payments run on a fake gateway until the client has Razorpay keys.

## 2. Decision log

### Product rules

- **D1 Booking length:**
  Single-day bookings only, 1 to 12 whole hours.
  No "Days" tab, no bookings that cross midnight.
  Multi-day (live-in nurses) is a later release.
- **D2 Start times:**
  On the hour only.
  The time grid shows only hours when at least one qualified nurse is on duty that day; times inside the notice period are greyed out.
- **D3 Duration limit:**
  The Duration screen offers only lengths that some free, qualified nurse (either gender) can cover from the chosen start.
- **D4 Gender step:**
  Shows which genders have a free nurse for the exact slot; an unavailable gender is disabled with "Change date or time".
  No fallback.
- **D5 Nurse qualifications:**
  Admin ticks which services each nurse can do (at least one).
  Every availability check filters by service.
  A service no active nurse can do is shown as "Not available right now".
- **D6 Nurse pick:**
  1) the nurse from this patient's last completed visit, if free; 2) fewest booked hours that day; 3) fewest booked hours that week; 4) lowest nurse id.
- **D7 Travel gap:**
  Admin setting "gap between visits", whole hours, default 1.
- **D8 Working hours:**
  Gender and at least one service are required on every nurse.
  A nurse with no working hours is never bookable.
  No enforcement toggle.
- **D9 Price:**
  `base_price x hours`, tax included, no extra fees.
  Amount is saved on the booking at creation and used for the order, receipts and refunds.
- **D10 Notice and window:**
  3 h minimum notice, 7 day window, one value for all services, editable in Settings.
  Checked on the server.
- **D11 Cancelling:**
  Only the admin cancels (kill switch).
  The user calls support.
- **D12 Refunds:**
  Always full, normal speed (5-7 working days).
  The client absorbs Razorpay's fee.
- **D13 Visit progress:**
  Automatic at start and end time, by the scheduler.
  Admin can correct.
- **D14 Location:**
  A map pin is required on every address and booking.
  Free-text addresses are removed.
- **D15 Contact phone:**
  Family members gain `sex` and `contact_phone`.
  Each booking saves its own `contact_phone`, pre-filled and editable.
- **D16 Service area:**
  No limit.
- **D17 Admin bookings:**
  Admins cannot create bookings.
  Every booking comes from the app.
- **D18 Profile photo:**
  Removed.
  Initials avatar instead.
- **D19 Language:**
  English at launch.
  All app strings in translation files (ARB) from day one, ready for Hindi.

### Accounts and messaging

- **D20 User login:**
  Phone number + OTP only, no password.
  One flow for login and signup; new users then give name and optional email.
  Sessions about 30 days.
- **D21 Admin login:**
  Email + password (bcrypt, min 10 chars, lockout after 5 tries for 15 min), 12 h sessions, reset link by email, plus authenticator-app 2-step codes (TOTP) with backup codes.
- **D22 Admin team:**
  Several admins with equal rights, managed in Settings > Team.
  Every admin action is written to an activity log shown on the booking's History.
- **D23 Messages:**
  Every SMS and email is a row in a `messages` table, sent and retried by the scheduler, with delivery status and Resend in the admin panel.
  Failed nurse messages appear under "Needs attention".
- **D24 Nurse visit details:**
  One SMS with a private visit link to a mobile page served by our backend: patient, tap-to-call phone, address with landmark, care type, Directions button.
  Random token, dies after the visit, shows "no longer assigned" after reassignment or cancellation.
  Opening it is logged.
  Condition notes never go in SMS.
- **D25 User notifications:**
  SMS only (no push) for confirmed, nurse changed, cancelled with refund.
- **D26 SMS provider:**
  Client registers DLT and opens a new MSG91 account in the business name.
  We prepare templates and guidance (`dlt-msg91-guide.html`).
- **D27 Email:**
  Brevo free plan from `noreply@<domain>`, with SPF, DKIM and DMARC on the client's domain.
- **D28 Account deletion:**
  In Profile, confirmed by OTP.
  Personal data erased; bookings and payments kept with personal details blanked.
  Upcoming confirmed booking: call support first.

### Platform and engineering

- **D29 Hosting:**
  Railway Hobby plan.
  Postgres on Railway.
  Production plus staging.
  Staging uses Railway Serverless (sleep when idle), which only works if it sends no outbound traffic for 5 minutes, so staging runs with `RUN_WORKER=false` and no idle database connections (`NullPool`).
  Staging jobs run on demand from an admin-only "run jobs now" endpoint; update-on-read keeps state correct meanwhile.
- **D30 Domains:**
  The client's existing domain: `api.<domain>`, `admin.<domain>`.
  Visit links and the delete-account page are served by the backend.
- **D31 Website pages:**
  The client's existing website hosts Terms, Privacy, Refund & Cancellation, Contact.
  We write the text for any missing page.
- **D32 Platforms:**
  Android only.
  Code stays iOS-ready but iOS is not set up, tested or published.
- **D33 Play Store:**
  Organization Play Console account in the client's name (needs a D-U-N-S number).
  App id derived from the domain, fixed in phase 0.
- **D34 Maps:**
  Google Maps SDK for Android, Places Autocomplete (New) with session tokens, Place Details Essentials, Geocoding, Maps Embed in admin.
  Keys restricted to app signature and admin domain, daily quotas under the free caps, $1 budget alert.
  Expected bill $0.
- **D35 Background jobs:**
  Procrastinate (Postgres-backed job queue) inside the backend process, with locking.
  Update-on-read stays as a safety net.
- **D36 CI:**
  GitHub repo, GitHub Actions on every push and PR, Railway deploys only after checks pass.
- **D37 Monitoring:**
  Deferred until after launch.
  Kept for launch: `/health` (Railway health check, scheduler heartbeat) and a nightly encrypted `pg_dump` to Backblaze B2 free tier, 14 copies, one restore test before launch.
- **D38 Payments now:**
  `PaymentGateway` interface: `FakeGateway` until keys exist, `RazorpayGateway` after.
  Razorpay webhook plus verify share one idempotent finalize function.

## 3. Stack

| Layer | Choice |
|---|---|
| Backend | Python 3.12, FastAPI, SQLAlchemy 2 async + asyncpg, Alembic, Pydantic v2 |
| Python tooling | uv (lockfile), ruff (lint and format), pyright (types), pytest + pytest-asyncio |
| Jobs | Procrastinate on the same Postgres |
| Database guards | Row locks plus a `btree_gist` exclusion constraint on nurse time ranges |
| API contract | OpenAPI from FastAPI; generated TypeScript client (`openapi-typescript` + `openapi-fetch`) for admin and generated Dart client for the app; CI fails if generated code is stale |
| Admin | React 18, Vite, TypeScript, TanStack Router + Query, shadcn/ui + Tailwind 4 (v1 tokens kept), react-hook-form + zod, Vitest, pnpm |
| App | Flutter (Android), Riverpod, go_router, freezed + json_serializable, Dio, `google_maps_flutter`, `geolocator`, Places via HTTP, `razorpay_flutter`, `sms_autofill`, ARB translations |
| Integrations | Razorpay, MSG91, Brevo, Google Maps Platform, Backblaze B2 |
| Infra | Railway (backend service, admin static service, Postgres), GitHub Actions |

Local tools: Node 26 and pnpm 12 are installed; Flutter and Docker need checking or installing before phases 0 and 4.
Pin versions (`.python-version`, `engines` + `packageManager`, Flutter version in CI) and match Railway's runtime to them.

## 4. Repo layout

```
backend/
  app/
    api/          thin FastAPI routers
    services/     booking, availability, assignment, payments, refunds, messages, lifecycle, visit_links, auth
    models/       SQLAlchemy models
    schemas/      Pydantic I/O
    jobs/         Procrastinate tasks and periodic jobs
    integrations/ razorpay, msg91, brevo, backblaze
    templates/    visit page, delete-account page (server-rendered HTML)
  alembic/
  tests/
admin/            React + TS
app/              Flutter
docs/             flow-v2.md, wireframes-v2.html, dlt-msg91-guide.html, this plan
.github/workflows/
docker-compose.yml  local Postgres
```

## 5. Data model (fresh Alembic baseline)

Times: slot columns are naive and mean IST wall-clock; audit timestamps are `timestamptz`; the DB session is UTC; IST conversion lives in one `timeutil` module.

| Table | Key columns |
|---|---|
| `users` | id, name, phone (nullable, partial unique index on verified phones), email (optional for users, required for admins), role `user`/`admin`, password_hash + totp_secret (admins only), deleted_at, created_at |
| `admin_backup_codes` | user_id, code_hash, used_at |
| `otps` | as v1 (channel, target, purpose, code_hash, attempts, request_ip, expiry) |
| `family_members` | id, user_id, name, age, sex, relation, contact_phone, medical_notes |
| `addresses` | id, user_id, label, house, area_line, city, state, pincode, landmark, latitude, longitude (required), is_default |
| `services` | id, name, description, base_price, active |
| `nurses` | id, name, phone, email, gender (required), experience_years, notes, is_active |
| `nurse_services` | nurse_id, service_id |
| `nurse_weekly_hours` | nurse_id, weekday, start_hour, end_hour |
| `nurse_day_overrides` | nurse_id, day, is_leave, start_hour, end_hour, note |
| `bookings` | id, user_id, member_id, service_id, slot_start, slot_end, hours, amount, nurse_gender_preference, status, hold_expires_at, patient name/age/sex/condition, contact_phone, address snapshot (text, landmark, lat, lng), cancel_reason, cancelled_by, cancelled_at, created_at |
| `booking_assignments` | booking_id, nurse_id, raw slot range (`tsrange`), active flag, assigned_at, ended_at; exclusion constraint: no two active rows overlap for one nurse |
| `payments` | id, booking_id (unique), gateway, order_id, payment_id, amount, status (`pending`, `completed`, `refund_pending`, `refunded`, `refund_failed`), refund_id, refunded_at |
| `messages` | id, booking_id, recipient type and phone/email, channel, template, payload, status, attempts, provider_ref, last_error, sent_at |
| `visit_links` | token (random), booking_id, nurse_id, expires_at, revoked_at, first_opened_at |
| `activity_log` | id, actor (admin, system, user), action, booking_id, nurse_id, details, created_at |
| `app_settings` | min_notice_minutes, booking_window_days, bookings_paused, travel_gap_hours, support_phone |

The travel gap is a setting that can change, so it is enforced in the service layer under the row lock, not in the constraint.

Statuses: `pending_payment`, `expired`, `confirmed`, `in_progress`, `completed`, `cancelled`.
`requested` does not exist.

## 6. Phases

Each phase ends with green CI and a working staging deploy.

### Phase 0: Repo and tooling

1. `git init`; move `flow-v2.md`, `wireframes-v2.html`, `dlt-msg91-guide.html` and this plan into `docs/`.
2. Copy v1 sources as reference starting points (`backend/` from `DRAPP-BACKEND`, `admin/` from `hospital-care-admin`, `app/` from `care_nest`); skip `cn_nurse`, `lib-user`, `lib-operator`, `dist`, `.env`, `.venv`, `node_modules`.
3. Backend: uv project, ruff, pyright, pytest; `docker-compose.yml` for local Postgres.
4. Admin: pnpm, TypeScript conversion scaffold, TanStack Router/Query, lint and build passing.
5. App: Riverpod, go_router, freezed scaffold; app id `<reversed-domain>.carenest` (placeholder until the domain is known); INTERNET permission in the main manifest.
6. GitHub Actions: backend (ruff, pyright, pytest with a Postgres service), admin (lint, typecheck, test, build), app (analyze, test, debug APK), generated-client freshness check.
7. Railway: production and staging environments, `railway.toml` per service, "wait for CI"; staging with Serverless on, `RUN_WORKER=false`, `NullPool`.
8. Root README with how to run each part.

### Phase 1: Backend foundations

1. `timeutil` (IST), settings table and `GET /settings/booking`, `GET`/`PATCH /admin/settings`.
2. Fresh baseline migration (section 5, plus Procrastinate's own schema at a pinned version) and seed script (first admin from env vars, services, test nurses).
3. User auth: `/auth/phone/send-otp`, `/verify-otp`, `/complete-signup`, logout, account deletion (`DELETE /users/me` with OTP).
4. Admin auth: login, TOTP setup and verify, backup codes, lockout, password reset email, team management endpoints.
5. Profile, family members (with sex and contact phone), addresses (pin required).
6. Services CRUD (admin).
7. Nurses CRUD with gender, services, weekly hours, day overrides (admin only; no nurse login, no public nurse endpoints).
8. Activity log helper used by every admin and system action.

### Phase 2: Booking engine

1. Availability service: on duty (weekly hours, overrides, leave), qualified for the service, not busy (active assignments, plus the current travel gap before and after), single day only.
2. Read endpoints: `GET /bookings/time-grid?service&date` (D2), `GET /bookings/max-duration?service&start` (D3), `GET /bookings/gender-availability?service&start&hours` (D4), `POST /bookings/quote` (D9).
3. `POST /bookings`: notice, window and paused checks; candidate selection; row locks ordered by nurse id; pick by D6; in the same transaction, deactivate expired holds of the candidate nurses before inserting, so a just-expired hold never trips the constraint; insert booking and assignment (the exclusion constraint is the final guard, mapped to a clean 409); 15 min hold.
4. Payments: `PaymentGateway` interface, `FakeGateway`, `RazorpayGateway`; `create-order` refuses expired or non-pending bookings; `finalize_payment` idempotent, accepts `pending_payment` and `expired`, keeps the nurse if still free, else reassigns (deactivating expired holds first, as in create), else cancels and refunds; webhook endpoint for Razorpay.
5. Refund service: idempotent, records refund id, `refund_failed` on error with scheduler retries and "Needs attention".
6. Scheduler jobs (Procrastinate): expire holds, move to `in_progress` and `completed`, send and retry messages, retry refunds, nightly encrypted backup, heartbeat for `/health`.
   The expiry job never touches a booking whose payment is completed.
7. Admin actions: kill switch (`POST /bookings/{id}/cancel`), reassign (with qualified-first nurse list), status correction, nurse unavailable for a date range (preview, then apply), "Needs attention" list, resend messages.
8. Messages: templates for every event in `flow-v2.md` section 8, MSG91 OTP and template SMS, Brevo email, dev mode logs instead of sending, staging sends SMS only to whitelisted numbers.
9. Visit links: token creation on confirm and reassign, revocation on cancel and reassign, public mobile page at `https://api.<domain>/v?k=...` (the registered DLT link prefix; links must not redirect), open tracking.
   Staging links on `*.up.railway.app` cannot be DLT-registered, so staging nurse messages go by email, unless an `api-staging.<domain>` custom domain fits within Railway's limits (to check).
10. Tests (DB-backed, fake gateway, mocked providers):
    - time grid, max duration and gender availability for mixed hours, leave, services and travel gap;
    - nurse pick order including continuity;
    - two concurrent creates for the last free nurse: one wins, one gets 409;
    - a new booking for a nurse whose hold expired before the expiry job ran succeeds;
    - notice boundary in IST, window edge, paused flag, midnight crossing rejected;
    - pay after hold expiry: keep, reassign and cancel-plus-refund paths; pay after the expiry job already ran;
    - verify and webhook both arriving: one finalize, no double refund;
    - kill switch on confirmed and in-progress, refund success and failure;
    - scheduler transitions; visit link expiry and revocation; account deletion anonymizes but keeps payments.

### Phase 3: Admin panel

Wireframes A1 to A15 are the layout reference; v1 design tokens and components stay (OKLCH colors, Inter, `StatusBadge`, flat cards).

1. Auth screens with TOTP setup and entry, forgot password.
2. Dashboard: Needs attention (refund failures, system cancels, failed nurse messages, nurses without hours), Today by nurse.
3. Bookings list and detail: requested gender, assigned nurse, payment and refund status, map (Maps Embed), messages with delivery status and Resend, visit link opened, History from the activity log.
4. Reassign dialog (A7), kill switch dialog with required reason and refund preview (A8), nurse unavailable flow (A9).
5. Nurses (A10): gender, services checklist, contact details, setup badges.
6. Availability editor (A11): weekly hours grid, month calendar for leave and one-off hours, booked-day warning with reassign or cancel.
7. Services (A12).
8. Settings (A13): booking rules, travel gap, support phone, pause switch, Team.
9. Profile (A14), Help (A15).
10. Vitest for status mapping, forms and dialogs; render every page in light and dark and compare with the wireframes.

### Phase 4: User app

Wireframe screens 1 to 26 are the layout reference.

1. Phone and OTP screens with SMS autofill, "Tell us about you" for new users.
2. Home, services, service detail with the paused banner.
3. Booking flow: patient, date and time grid, duration (capped), gender, patient details and contact phone, address (saved, current location, pick on map, address details), review with backend quote, payment (fake sheet now, Razorpay later, checkout timeout = hold time left), confirmed screen.
4. Handle "no nurse free" and "hold expired" by returning to the time step; always start a fresh booking after success or exit.
5. My bookings: current, history, detail with Call support, cancelled view with reason and refund status.
6. Profile: edit (initials avatar), family members, addresses (map), delete account, privacy policy link.
7. ARB strings for everything; human status labels.
8. Tests: providers, time grid and duration rules, gender step, booking flow widget test with a fake API.

### Phase 5: Launch preparation

1. Plug in real keys as they arrive: Razorpay (test, then live, auto-capture on, webhook), MSG91 templates, Maps keys, Brevo domain records.
2. Release signing, Play listing, Data safety form, Health apps declaration, privacy and delete-account URLs.
3. Internal test track with the client's staff and a few nurses.
4. Restore test of a backup into staging.
5. End-to-end run on a real Android phone: sign up, book, pay, nurse SMS and visit page, reassign, kill switch with refund, account deletion.

### Phase 6: Go-live and after

1. Production deploy, real nurses entered with hours and services, public release.
2. After launch: monitoring (Sentry, Crashlytics, uptime alerts), multi-day bookings, WhatsApp channel, Hindi, iOS, push notifications, phone bookings by admins.

## 7. Client to-do (start now)

| Item | Why | Lead time |
|---|---|---|
| DLT registration + sender ID + templates (see `dlt-msg91-guide.html`) | No SMS, so no user login in production | 1-3 weeks |
| MSG91 account in the business name, KYC | Sends the SMS | About a day |
| D-U-N-S number, then Play Console organization account ($25) | Publishing the app | Days to weeks |
| Razorpay business account and KYC | Live payments; test keys come first | Days |
| Google Maps Platform billing account | Maps, search, address lookup | Same day |
| Website pages: Terms, Privacy, Refund & Cancellation, Contact (we supply text) | Razorpay activation and Play listing | Depends on their web person |
| Domain name and DNS access | API, admin, visit links, email records, app id | Same day |
| Confirm with the client | Multi-day bookings later; login is phone + code; no profile photo | - |

## 8. Risks

- **DLT and D-U-N-S delays:**
  They are the critical path.
  Building continues on staging; only the public launch waits.
- **Auto-confirm trusts admin data:**
  Wrong hours or services mean a paid booking with the wrong nurse.
  Required gender and services, the availability editor, the kill switch and "Needs attention" are the safeguards.
- **Nurse misses an SMS:**
  Retries, email copy, visit link "opened" tracking and Today by nurse in the dashboard.
- **Concurrency and money bugs:**
  Row locks, the exclusion constraint, idempotent finalize and refund, and the phase 2 test list.
- **Railway Hobby limits:**
  Community support and 7-day logs.
  Upgrade to Pro is one click if needed.

## 9. Open items

- Client's domain and DNS provider (placeholders until then: app id, visit link host, email sender, subdomains).
- Which of the website pages already exist.
- Whether Railway Hobby's 2 custom domains are per service or per project (decides whether staging gets `api-staging.<domain>`).

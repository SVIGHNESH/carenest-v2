# CareNest: Product Flow v2 (plan)

Version 2.0 draft, 2026-10-10.
This replaces the booking part of `flow.md` v1.0.
Signup, verification, services, family members and addresses are unchanged.

## 1. What the client asked for

1. The user picks **male or female nurse**, not a specific nurse.
2. The **nurse app is scrapped**.
3. Nurse **availability is set by the admin** in the admin panel.
4. A **minimum notice time** before a booking can start, set in the admin panel.
5. **No confirmation step**: once the user pays, the booking is final.
6. An admin **kill switch** to cancel a booking in any unforeseen situation.

## 2. Where the code is today

This plan is written against the code, not against `flow.md` v1.0, because the two differ.

| Area | Today in code | Note |
|---|---|---|
| Confirmation | `POST /payments/verify` already sets `confirmed` | The `awaiting_admin` / `rejected` flow from v1.0 was never built, so nothing to remove in the backend. |
| Admin confirm | `PATCH /bookings/{id}/confirm` exists and the panel has a Confirm action | Becomes "reassign nurse" only. |
| Cancel and refund | No cancel endpoint, no refund code | Admin can only set status `cancelled` by hand, with no refund. |
| Nurse gender | No column on `nurses` | New. |
| Nurse choice | User picks a named nurse in `nurse_selection_screen.dart` | Replaced. |
| Availability | Only the nurse can write it (`/nurses/me/availability`); the panel has a read-only viewer | Moves to admin. |
| Booking window | App hardcodes "tomorrow only" in `calendar_selection_screen.dart` | Replaced by the admin setting. |
| Visit progress | Nurse app sets `in_progress` / `completed` | Needs a replacement. |
| Alerts | Email only; SMS is used for OTP only | Nurse now depends fully on SMS and email. |
| Paid-but-nurse-taken race | Nurse is unassigned and a note is left for a human | Must resolve itself now. |

## 3. Actors after the update

- **User**: books, chooses male or female nurse, pays.
- **Admin**: owns nurses, their gender, their availability, the notice time, and the kill switch.
- **Nurse**: has no app and no login. Receives visit details by SMS and email.
- **System**: assigns the nurse, confirms on payment, moves the visit through its states, refunds.

## 4. User app flow

```
Service Detail ─▶ Who is the patient ─▶ Date & Time ─▶ Duration ─▶ Male or Female nurse ─▶ Patient details & Address ─▶ Review ─▶ Pay ─▶ Booking confirmed
```

1. **Date & Time**: the picker only offers start times that are at least the notice time away, and no further ahead than the admin's booking window.
   If bookings are paused by the admin, the Book Now button shows "Bookings are temporarily unavailable".
2. **Duration**: unchanged.
3. **Male or Female nurse**: two large options.
   The backend says which genders have a free nurse for the chosen slot.
   An option with no free nurse is disabled with "Not available for this time", and the user can go back and change the time.
   No nurse names or list are shown.
4. **Who is the patient** (first step) and **Patient details**: unchanged.
   **Address** is now set from the map or current location (section 13).
5. **Review**: shows "Nurse: Female" (or Male) instead of a nurse name, plus the backend total.
6. **Pay**: on create, the backend picks a free nurse of that gender and holds them for 15 minutes.
   On successful payment the booking is `confirmed` immediately.
7. **Success screen**: "Booking confirmed" with the assigned nurse's name, date and time.
   No "waiting for confirmation" wording anywhere.

After booking:

- **Current bookings**: `confirmed`, `in_progress`.
- **History**: `completed`, `cancelled` (with the reason and refund status).
- There is no cancel button in the app.
  To cancel, the user calls support and the admin uses the kill switch.

## 5. Booking lifecycle

```
                 pay (signature OK)        slot start time         slot end time
pending_payment ───────────────▶ confirmed ───────────▶ in_progress ───────────▶ completed
      │                              │                       │
      │ abandoned (15 min hold       │ admin kill switch     │ admin kill switch
      │  expires)                    ▼                       ▼
      └──▶ expired, hidden        cancelled               cancelled
                                 (refund issued)        (refund issued)
```

| Status | Meaning | Holds the nurse? | Who moves it on |
|---|---|---|---|
| `pending_payment` | created, checkout not finished | yes, 15 min | user (pay) |
| `confirmed` | paid, nurse assigned | yes | system (start time), admin (cancel, reassign) |
| `in_progress` | visit under way | yes | system (end time), admin (cancel, mark completed) |
| `completed` | done | no | terminal |
| `cancelled` | killed by admin, or auto-cancelled by the system | no | terminal |

`requested` is removed everywhere (backend `VALID_STATUSES`, `BLOCKING_STATUSES`, admin `status.js`).

### Rules

- **Nurse pick**: among active nurses of the chosen gender who are free and on duty for the slot, take the one with the fewest bookings that day.
- **No double booking**: the pick and the insert run in one transaction with the candidate nurse row locked, so two users cannot get the same nurse for the same time.
- **Payment arrives after the hold expired and the nurse is gone**: the system assigns another free nurse of the same gender.
  If none is free, the booking is auto-cancelled, fully refunded, and the user and admin are told.
  No booking is ever left paid without a nurse.
- **Visit progress**: with no nurse app, the system moves `confirmed` to `in_progress` at slot start and to `completed` at slot end.
  The admin can correct either from the panel.
  The backend has no scheduler and the server can sleep, so the status is brought up to date whenever bookings are read, not by a background job.
- **Notice time**: checked on the server in both the availability call and booking creation, so an old app version cannot bypass it.

## 6. Admin panel

### 6.1 Nurses page

- **Gender** (Male / Female) is a required field on create and edit.
  Existing nurses have no gender, and a nurse without one is not offered to users until it is filled in.
- Email and temporary password are no longer login credentials.
  Email and phone stay, because that is how the nurse receives visit details.
- **Availability editor** replaces the read-only viewer:
  - weekly working hours per nurse (for example Mon to Sat, 08:00 to 20:00),
  - leave days and one-off hour changes on a calendar.
- Recommended rule change: a nurse with **no working hours set is not bookable**.
  Today "no declaration" means available all day, which was safe when a nurse or admin reviewed each booking, and is not safe when bookings confirm themselves.
- Marking leave on a day that already has bookings shows those bookings and offers reassign or cancel for each.

### 6.2 Settings page (new)

| Setting | Meaning | Suggested default |
|---|---|---|
| Minimum notice time | Shortest gap between "now" and a booking's start | 3 hours |
| Booking window | How many days ahead a user can book | 7 days |
| Pause new bookings | Global switch; stops all new bookings, existing ones are untouched | off |

### 6.3 Bookings page

- The Confirm action and the "pending" filter are removed.
- **Reassign nurse**: lists free nurses for the slot, same gender first.
- **Cancel booking (kill switch)**: see section 7.
- New columns: nurse gender requested, refund status, cancel reason.

### 6.4 Dashboard

- A "needs attention" list: refunds that failed, and bookings the system auto-cancelled.

## 7. Kill switch

One action, available on any booking that is not already `completed` or `cancelled`, including a visit that is `in_progress`.

1. Admin clicks **Cancel booking** and must type a reason.
2. The booking becomes `cancelled`, and the nurse's slot is freed at once.
3. If the booking was paid, the Razorpay refund is issued automatically.
   If the refund call fails, the booking is still cancelled, payment is marked `refund_failed`, and it appears under "needs attention" for a manual refund.
4. The user gets an SMS with the reason and refund note.
   The nurse gets an SMS that the visit is off.
5. Who cancelled, when and why are stored on the booking.

Two wider switches for bigger events:

- **Nurse unavailable**: pick a nurse and a date range, see every affected booking, then reassign all that can be reassigned and cancel the rest in one step.
- **Pause new bookings**: the global toggle in Settings.

## 8. Notifications

| Event | User | Admin | Nurse |
|---|---|---|---|
| Booking paid and confirmed | SMS with nurse name, date, time | email summary | SMS + email with patient, phone, address, time |
| Nurse reassigned | SMS with new nurse name | - | old nurse: SMS "visit removed"; new nurse: full details |
| Admin cancels (kill switch) | SMS with reason and refund note | - | SMS "visit cancelled" |
| System auto-cancels (no nurse free) | SMS with refund note | dashboard + email | - |
| Refund failed | - | dashboard + email | - |

SMS today only covers OTP, so a transactional MSG91 template (DLT-approved) is needed before the nurse can rely on it.

## 9. Backend changes

### Data model

| Table | Change |
|---|---|
| `nurses` | add `gender`; login fields (`password_hash`, `is_password_reset`) no longer used |
| `nurse_weekly_hours` | new: nurse, weekday, start time, end time |
| `nurse_availability` | kept for leave days and one-off overrides, now written by admin |
| `bookings` | add `nurse_gender_preference`, `cancel_reason`, `cancelled_by`, `cancelled_at`; drop status `requested` |
| `payments` | add `razorpay_refund_id`, `refunded_amount`, `refunded_at`; new statuses `refunded`, `refund_failed` |
| `app_settings` | new: `min_notice_minutes`, `booking_window_days`, `bookings_paused` |

### API

| Method & path | Who | Change |
|---|---|---|
| `GET /settings/booking` | public | notice time, window, paused flag, for the app's date picker |
| `PATCH /admin/settings` | admin | edit the three settings |
| `GET /bookings/gender-availability?slot_start=&slot_end=` | user | new: returns `{male: bool, female: bool}` for the slot |
| `GET /nurses/availability/{date}` | admin | kept as the nurse list for the Reassign dialog; becomes admin-only once the new app is live (today it is public and returns nurse phone numbers) |
| `POST /bookings` | user | takes `nurse_gender` instead of `nurse_id`; enforces notice time, window, paused flag; auto-assigns |
| `POST /payments/verify` | user | auto-reassign or auto-cancel and refund on a lost hold |
| `POST /bookings/{id}/cancel {reason}` | admin | kill switch with refund |
| `PATCH /bookings/{id}/reassign {nurse_id}` | admin | replaces `/confirm` |
| `POST /admin/nurses/{id}/unavailable {from, to, action}` | admin | bulk reassign or cancel |
| `PUT /nurses/{id}/weekly-hours`, `PUT` / `DELETE /nurses/{id}/availability/{day}` | admin | availability editor |
| `POST /nurses`, `PATCH /nurses/{id}` | admin | `gender` required; no temporary password |

Removed: `/nurses/login`, `/nurses/reset-password`, `/nurses/me/availability` (all three), `/bookings/assigned-to-me`, `/bookings/{id}/confirm`, the nurse branch of `PATCH /bookings/{id}/status`, and the nurse token dependencies.

Removed folders: `DR-Backend/cn_nurse/` and the stale `DR-Backend/lib-operator/`.

## 10. Implementation order

1. **Data first**: the migration adds gender and weekly hours without enforcing them.
   The admin fills in gender and working hours for every existing nurse.
   Only then are the "no gender" and "no hours" rules switched on, otherwise no nurse is bookable on release day.
2. **Backend**: migration, settings, gender, admin-owned availability, auto-assign with locking, notice-time checks, kill switch and refunds, timed status changes, SMS alerts, removal of nurse auth, tests.
3. **Admin panel**: gender field, availability editor, Settings page, kill switch and reassign on Bookings, bulk nurse-unavailable action, needs-attention list.
4. **User app**: gender step replacing nurse selection, date picker driven by settings, new success and booking-detail wording, removal of the nurse list.
5. **Cleanup**: delete the nurse app folders, update the README and Postman collection.

The backend must keep accepting `nurse_id` on `POST /bookings`, and keep the nurse list endpoint open, until the new app build is live.
Otherwise the published app breaks.

## 11. Questions for the client

1. **Notice time**: what value, and one value for everything or different per service?
   Plan assumes one global value.
2. **Booking window**: how many days ahead can a user book?
   Today it is tomorrow only.
3. **User cancellation**: plan assumes only the admin can cancel.
   Should the user be able to cancel from the app at all?
4. **Refund on kill switch**: always full, or can the admin choose an amount when a visit is already under way?
5. **Visit start and end**: is automatic by the clock acceptable, or should the admin mark them by hand?
6. **Nurse working hours**: is "no hours set means not bookable" acceptable?
7. **Gender not available**: just disable the option, or offer the other gender as a fallback?
8. **Service area**: should a booking be refused when the pin is outside the area you serve?
9. **Map service**: plan assumes Google Maps, which is billed by usage beyond its free allowance.

## 12. Risks

- **No human check before confirmation.**
  Wrong availability data in the admin panel now becomes a confirmed, paid booking with a nurse who cannot attend.
  The availability editor and the kill switch are the two safeguards, so both must be solid before auto-confirm relies on them.
- **Nurse has no app.**
  If the SMS does not arrive, the nurse does not know about the visit.
  The email copy and the admin's daily view of each nurse's bookings are the backstop.
- **Time zone.**
  Slot times are stored without a zone, and the notice-time check compares them to "now".
  The zone must be fixed to IST explicitly in the backend before this check is added.

## 13. Visit location from the map

Added 2026-10-10 at the client's request.
Today the address is typed text only: the app has no map, and the backend stores no coordinates.

**User app**

- The address step offers three ways to say where the nurse should come: a saved address, **current location**, or **pick on map**.
- The map screen has a search box, a draggable pin and a "Use my current location" button, and shows the address the pin resolves to.
- After the pin, the user adds house or flat number and an optional landmark, and can save the address for next time.
- If the user refuses location permission, search and dragging the pin still work.
- Add Address in the profile uses the same map screen.

**Backend**

- `addresses` gains `latitude`, `longitude`, `landmark`.
- `bookings` gains `service_latitude`, `service_longitude`, `service_landmark`, copied at booking time so a later address edit does not move a past visit.
- `POST /bookings` and the address endpoints accept the coordinates; `BookingOut` returns them plus a ready `maps_url`.
- A typed address with no pin stays allowed until the new app build is live, then the pin becomes required.

**Nurse and admin**

- The nurse's new-visit SMS and email carry a Google Maps directions link to the exact pin.
- The admin's booking detail shows the pin on a map, with "Open in Google Maps" and "Resend location to nurse".

**Needs from the client**

- A Google Maps Platform account with billing enabled (Maps SDK for Android and iOS, Places, Geocoding).
- A decision on whether bookings are limited to a service area.

## 14. Wireframes

Every screen of the user app and admin panel is drawn in `processflow/wireframes-v2.html`.

# User app status

Location: `app/`.
Updated as work proceeds.

## Done
- Scaffold (android, ios, linux), dependencies, Inter font bundled as asset.
- Data layer: Dio ApiClient, ApiException (detail + X-Error-Code), models, repositories (hand written client, see README).
- Design system (`lib/ui`): tokens (OKLCH to sRGB, light/dark), theme, buttons, cards, status chip, banners, step header, bottom action bar, text fields, select tiles, async body.
- Auth: splash, phone, OTP (60 s resend, autofill guarded), "Tell us about you".
- Home, services list, service detail (paused banner, unavailable state).
- Booking flow: patient, date and time, duration, nurse gender, details and address, map picker (Google or simulated), address details, review with backend quote, payment (fake sheet / Razorpay launcher), confirmed. 409 codes return to the time step with choices kept.
- My bookings (current/history), detail with Call support, cancelled view with refund info.
- Profile: edit, family, addresses (map picker), privacy link, delete account (OTP), logout.
- ARB strings for everything (`lib/l10n/app_en.arb`).
- Real backend smoke script (`tool/smoke.dart`) passes: login, services, time grid, create booking, fake pay, fetch.
- API contract check (`tool/check_api_contract.dart`, `tool/generate_api.sh`).
- README.

## In progress
- Widget tests run, APK build, screenshots on Linux desktop.

## Blocked
- Nothing. Note: the machine has about 3 GB RAM, Gradle heap lowered to 1.5 GB; JDK 17 required (JDK 27 default is rejected).

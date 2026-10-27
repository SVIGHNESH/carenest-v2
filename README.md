# CareNest v2

Home-care nursing bookings: user app (Flutter, Android), admin panel (React), backend (FastAPI).
Plan and decisions: `docs/IMPLEMENTATION_PLAN.md`.
Build progress: `docs/PROGRESS.md`.

## Run locally
Database: `docker compose up -d db`, or any Postgres 17+ on port 54329 with a `carenest` database and the `btree_gist` extension.

Backend:
```
cd backend
uv sync
cp .env.example .env
uv run alembic upgrade head
uv run python -m app.seed --demo
uv run uvicorn app.main:app --reload
```
With no provider keys set, OTP codes and emails are written to the server log and payments use the fake gateway.

Admin: `cd admin && pnpm install && pnpm dev` (http://localhost:5173).
The first admin comes from `FIRST_ADMIN_EMAIL` and `FIRST_ADMIN_PASSWORD`; the first sign-in asks you to set up an authenticator app.

App: see `app/README.md`.

## Checks (same as CI)
- Backend: `uv run ruff check . && uv run ruff format --check . && uv run pyright && uv run pytest`
- Admin: `pnpm lint && pnpm typecheck && pnpm test && pnpm build`
- API contract: `uv run python scripts/dump_openapi.py ../docs/openapi.json`, then `pnpm gen:api` in `admin`.

## Placeholders to replace
Domain, app id, email sender, MSG91 and Brevo keys, Razorpay keys, Google Maps keys, Backblaze B2 keys.
All are environment variables listed in `backend/.env.example`.

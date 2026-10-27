# CareNest v2 build progress

Path: `/home/vighnesh/Work/DRAPP(CARENEST) V2`.
Plan: `docs/IMPLEMENTATION_PLAN.md` (wins over `flow-v2.md`).

## Local dev
Postgres (no Docker): `pg_ctl -D ~/.local/share/carenest-pg -o "-p 54329 -k /tmp -c listen_addresses=127.0.0.1" start`.
Backend: `cd backend && RUN_WORKER=true uv run uvicorn app.main:app --port 8000`.
Backend tests: `cd backend && uv run pytest -q` (47 pass), `uv run ruff check .`, `uv run pyright`.
API contract: `cd backend && uv run python scripts/dump_openapi.py ../docs/openapi.json`, then `cd admin && pnpm gen:api`.
Seed: `uv run python -m app.seed --demo` (admin from FIRST_ADMIN_EMAIL / FIRST_ADMIN_PASSWORD in env, defaults admin@example.com / change-me-please; TOTP is set up on first login).
Flutter: `~/development/flutter/bin`, Android SDK `~/Android/Sdk`.

## Status
- Phase 0: done (Dockerfile, railway.toml, docker-compose, GitHub workflows, README, restore script). Not done on purpose: GitHub repo, Railway project (outward-facing, needs the owner).
- Phase 1 and 2 (backend): done, committed, tests green.
- Phase 3 (admin): pages written; lint, typecheck, 12 vitest tests and build pass. Rendered in light and dark incl. dialogs, mobile width, real TOTP sign-in. Done.
- Phase 4 (app): delegated to a background agent; progress in `docs/app-status.md`.
- Phase 5/6: code-side items only (signing placeholders, backup/restore scripts); the rest waits on the client to-do list.

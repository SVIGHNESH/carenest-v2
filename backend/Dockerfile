FROM python:3.12-slim-trixie
# pg_dump for the nightly backup must be at least the server's major version (Render Postgres 17).
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client-17 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /srv
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --no-install-project
COPY . .
ENV PATH="/srv/.venv/bin:$PATH" PYTHONUNBUFFERED=1
# Migrations and the idempotent seed (first admin, services; demo nurses when SEED_DEMO=true)
# run before the server starts (one instance, so no race).
CMD ["sh", "-c", "alembic upgrade head && python -m app.seed $([ \"$SEED_DEMO\" = \"true\" ] && echo --demo) && uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]

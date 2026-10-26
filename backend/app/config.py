"""All configuration in one place.

Every outside service has a placeholder default so the app runs locally and in
tests with nothing configured. Real values arrive through environment
variables (see `.env.example`).
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Core
    ENVIRONMENT: str = "development"  # development | staging | production | test
    DATABASE_URL: str = "postgresql+asyncpg://carenest@127.0.0.1:54329/carenest"
    SECRET_KEY: str = "dev-secret-change-me-dev-secret-change-me"
    USER_TOKEN_DAYS: int = 30
    ADMIN_TOKEN_HOURS: int = 12
    # Sleeping staging: no idle pooled connections so Railway can scale to zero.
    DB_NULL_POOL: bool = False
    RUN_WORKER: bool = True
    # Staging links live on *.up.railway.app and cannot be DLT registered: nurses get email only there.
    NURSE_SMS_ENABLED: bool = True
    RUN_MIGRATIONS_ON_STARTUP: bool = False

    # Placeholders: the client's domain is not known yet.
    DOMAIN: str = "carenest.example"
    API_BASE_URL: str = "http://localhost:8000"
    ADMIN_BASE_URL: str = "http://localhost:5173"
    APP_ID: str = "example.carenest"
    EMAIL_FROM: str = "noreply@carenest.example"
    FIRST_ADMIN_EMAIL: str = "admin@example.com"
    FIRST_ADMIN_PASSWORD: str = "change-me-please"
    FIRST_ADMIN_NAME: str = "CareNest Admin"

    # SMS (MSG91). Empty auth key = log instead of send.
    MSG91_AUTH_KEY: str = ""
    MSG91_SENDER_ID: str = "CRNEST"
    MSG91_OTP_TEMPLATE_ID: str = ""
    # Per message template: MSG91 template id (DLT-linked), keyed by template name.
    MSG91_TEMPLATE_IDS: str = ""  # "visit_new=abc,visit_removed=def,..."
    # Staging: only these numbers receive SMS (comma separated, +91...). Empty = all.
    SMS_WHITELIST: str = ""

    # Email (Brevo). Empty key = log instead of send.
    BREVO_API_KEY: str = ""
    ADMIN_NOTIFY_EMAIL: str = "admin@example.com"

    # Payments
    PAYMENT_GATEWAY: str = "fake"  # fake | razorpay
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""

    # Maps (server side geocoding is optional; keys restricted per D34)
    GOOGLE_MAPS_API_KEY: str = ""

    # Backups to Backblaze B2 (S3 compatible)
    B2_ENDPOINT: str = ""
    B2_KEY_ID: str = ""
    B2_APP_KEY: str = ""
    B2_BUCKET: str = ""
    BACKUP_ENCRYPTION_KEY: str = ""  # Fernet key
    BACKUP_KEEP: int = 14

    # Admin-only "run jobs now" is always available; this guards the heartbeat age.
    HEARTBEAT_MAX_AGE_SECONDS: int = 180

    @property
    def is_prod(self) -> bool:
        return self.ENVIRONMENT == "production"

    @property
    def sms_whitelist(self) -> set[str]:
        return {p.strip() for p in self.SMS_WHITELIST.split(",") if p.strip()}

    @property
    def template_ids(self) -> dict[str, str]:
        out: dict[str, str] = {}
        for pair in self.MSG91_TEMPLATE_IDS.split(","):
            if "=" in pair:
                k, v = pair.split("=", 1)
                out[k.strip()] = v.strip()
        return out

    @property
    def psycopg_url(self) -> str:
        return self.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()

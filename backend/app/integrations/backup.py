"""Nightly encrypted pg_dump to Backblaze B2 (S3 compatible). No-op until configured."""

import asyncio
import logging
import subprocess
from datetime import datetime, timezone

from cryptography.fernet import Fernet

from app.config import settings

logger = logging.getLogger(__name__)


def configured() -> bool:
    return all(
        [settings.B2_ENDPOINT, settings.B2_KEY_ID, settings.B2_APP_KEY, settings.B2_BUCKET, settings.BACKUP_ENCRYPTION_KEY]
    )


def _dump() -> bytes:
    url = settings.psycopg_url
    return subprocess.run(["pg_dump", "--format=custom", "--no-owner", url], check=True, capture_output=True).stdout


def _client():
    import boto3

    return boto3.client(
        "s3", endpoint_url=settings.B2_ENDPOINT, aws_access_key_id=settings.B2_KEY_ID, aws_secret_access_key=settings.B2_APP_KEY
    )


def _run_backup() -> str:
    data = Fernet(settings.BACKUP_ENCRYPTION_KEY.encode()).encrypt(_dump())
    key = f"carenest/{settings.ENVIRONMENT}/{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.dump.enc"
    s3 = _client()
    s3.put_object(Bucket=settings.B2_BUCKET, Key=key, Body=data)
    prefix = f"carenest/{settings.ENVIRONMENT}/"
    objs = sorted(s3.list_objects_v2(Bucket=settings.B2_BUCKET, Prefix=prefix).get("Contents", []), key=lambda o: o["Key"])
    for old in objs[: max(0, len(objs) - settings.BACKUP_KEEP)]:
        s3.delete_object(Bucket=settings.B2_BUCKET, Key=old["Key"])
    return key


async def run_backup() -> str | None:
    if not configured():
        logger.warning("Backup skipped: B2 / encryption key not configured")
        return None
    return await asyncio.to_thread(_run_backup)

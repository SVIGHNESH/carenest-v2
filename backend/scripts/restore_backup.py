"""Restore an encrypted backup into a database (use staging for the pre-launch restore test).

Usage: uv run python scripts/restore_backup.py <backup-key-or-local-file> <target-postgres-url>
Needs BACKUP_ENCRYPTION_KEY and (for B2 keys) the B2_* settings.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from cryptography.fernet import Fernet

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.config import settings  # noqa: E402


def main(source: str, target_url: str) -> None:
    if Path(source).exists():
        blob = Path(source).read_bytes()
    else:
        from app.integrations.backup import _client

        blob = _client().get_object(Bucket=settings.B2_BUCKET, Key=source)["Body"].read()
    data = Fernet(settings.BACKUP_ENCRYPTION_KEY.encode()).decrypt(blob)
    with tempfile.NamedTemporaryFile(suffix=".dump") as f:
        f.write(data)
        f.flush()
        subprocess.run(["pg_restore", "--clean", "--if-exists", "--no-owner", "-d", target_url, f.name], check=True)
    print("restored")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

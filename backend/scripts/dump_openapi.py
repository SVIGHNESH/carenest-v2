"""Write openapi.json without touching the database (CI uses this for client generation)."""

import json
import os
import sys
from pathlib import Path

os.environ.setdefault("RUN_WORKER", "false")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.main import create_app  # noqa: E402

out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("openapi.json")
out.write_text(json.dumps(create_app().openapi(), indent=2, sort_keys=True) + "\n")
print(f"wrote {out}")

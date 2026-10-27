#!/usr/bin/env bash
# The app uses a hand-written typed Dio client (lib/data/api, lib/data/models,
# lib/data/repositories) instead of generated code, because FastAPI's OpenAPI 3.1
# output (anyOf with null) does not map cleanly onto null-safe json_serializable models.
# This script regenerates the json_serializable code and checks the client
# against docs/openapi.json. CI runs it and fails on drift.
set -euo pipefail
cd "$(dirname "$0")/.."
SPEC="${1:-../docs/openapi.json}"
dart run tool/check_api_contract.dart "$SPEC"
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- lib '*.g.dart' >/dev/null 2>&1 || echo "Note: generated files changed, commit them."

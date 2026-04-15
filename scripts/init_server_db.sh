#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DB_PATH="${1:-/data/prod/rd/vac/waferdb.sqlite}"

python3 "$ROOT_DIR/scripts/init_db.py" --db "$TARGET_DB_PATH"

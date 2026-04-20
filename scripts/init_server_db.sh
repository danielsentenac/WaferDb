#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/load_site_config.sh"

TARGET_DB_PATH="${1:-$WAFERDB_DB_PATH}"

umask 0002
python3 "$ROOT_DIR/scripts/init_db.py" --db "$TARGET_DB_PATH"
chmod g+rw "$TARGET_DB_PATH" 2>/dev/null || true

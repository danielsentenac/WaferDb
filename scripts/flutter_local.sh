#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/load_site_config.sh"

if [[ $# -eq 0 ]]; then
    echo "Usage: bash scripts/flutter_local.sh <flutter arguments>" >&2
    exit 1
fi

if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="flutter"
elif [[ -x "$HOME/.tooling/flutter/bin/flutter" ]]; then
    FLUTTER_BIN="$HOME/.tooling/flutter/bin/flutter"
else
    echo "Flutter executable not found in PATH or \$HOME/.tooling/flutter/bin/flutter" >&2
    exit 1
fi

EXTRA_ARGS=()
case "$1" in
    run|build|test)
        EXTRA_ARGS=(
            "--dart-define=WAFERDB_API_BASE=$WAFERDB_API_BASE"
            "--dart-define=WAFERDB_DARKFIELD_ROOT=$WAFERDB_DARKFIELD_ROOT"
        )
        ;;
esac

if [[ "$#" -ge 2 && "$1" == "build" && "$2" == "apk" ]]; then
    HAS_BUILD_NUMBER=0
    for arg in "$@"; do
        if [[ "$arg" == --build-number=* ]] || [[ "$arg" == "--build-number" ]]; then
            HAS_BUILD_NUMBER=1
            break
        fi
    done
    if [[ "$HAS_BUILD_NUMBER" -eq 0 ]]; then
        EXTRA_ARGS+=("--build-number=$(date +%s)")
    fi
fi

cd "$ROOT_DIR/waferdb_app"
exec "$FLUTTER_BIN" "$@" "${EXTRA_ARGS[@]}"

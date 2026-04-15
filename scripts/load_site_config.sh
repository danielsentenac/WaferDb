#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_ENV_FILE="${WAFERDB_SITE_ENV_FILE:-$ROOT_DIR/config/site.env.local}"

if [[ -f "$SITE_ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SITE_ENV_FILE"
fi

: "${WAFERDB_SCHEME:=http}"
: "${WAFERDB_HOST:=127.0.0.1}"
: "${WAFERDB_PORT:=8081}"
: "${WAFERDB_CONTEXT_PATH:=/WaferDb}"
: "${WAFERDB_DB_PATH:=$ROOT_DIR/data/waferdb.sqlite}"
: "${WAFERDB_DARKFIELD_ROOT:=$ROOT_DIR/data/darkfield}"
: "${WAFERDB_ALLOWED_ORIGIN:=*}"
: "${WAFERDB_DIST_LABEL:=local}"

if [[ "$WAFERDB_CONTEXT_PATH" != /* ]]; then
    WAFERDB_CONTEXT_PATH="/$WAFERDB_CONTEXT_PATH"
fi
if [[ "$WAFERDB_CONTEXT_PATH" != "/" ]]; then
    WAFERDB_CONTEXT_PATH="${WAFERDB_CONTEXT_PATH%/}"
fi

if [[ -n "${WAFERDB_API_BASE:-}" ]]; then
    WAFERDB_API_BASE="${WAFERDB_API_BASE%/}"
    if [[ "$WAFERDB_API_BASE" == */api ]]; then
        WAFERDB_APP_BASE="${WAFERDB_API_BASE%/api}"
    else
        WAFERDB_APP_BASE="$WAFERDB_API_BASE"
        WAFERDB_API_BASE="${WAFERDB_API_BASE%/}/api"
    fi
else
    PORT_SEGMENT=""
    if [[ -n "${WAFERDB_PORT:-}" ]]; then
        PORT_SEGMENT=":$WAFERDB_PORT"
    fi
    WAFERDB_APP_BASE="$WAFERDB_SCHEME://$WAFERDB_HOST$PORT_SEGMENT$WAFERDB_CONTEXT_PATH"
    WAFERDB_API_BASE="$WAFERDB_APP_BASE/api"
fi

export ROOT_DIR
export SITE_ENV_FILE
export WAFERDB_SCHEME
export WAFERDB_HOST
export WAFERDB_PORT
export WAFERDB_CONTEXT_PATH
export WAFERDB_DB_PATH
export WAFERDB_DARKFIELD_ROOT
export WAFERDB_ALLOWED_ORIGIN
export WAFERDB_DIST_LABEL
export WAFERDB_APP_BASE
export WAFERDB_API_BASE

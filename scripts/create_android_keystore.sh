#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/waferdb_app/android"
KEYSTORE_FILE="$ANDROID_DIR/waferdb-release.jks"
KEY_PROPERTIES_FILE="$ANDROID_DIR/key.properties"
KEY_ALIAS="${WAFERDB_ANDROID_KEY_ALIAS:-waferdb}"
STORE_PASSWORD="${WAFERDB_ANDROID_STORE_PASSWORD:-}"
KEY_PASSWORD="${WAFERDB_ANDROID_KEY_PASSWORD:-}"
DNAME="${WAFERDB_ANDROID_DNAME:-CN=WaferDB, OU=VIRGO, O=INFN, C=IT}"

if [[ -z "$STORE_PASSWORD" ]]; then
    STORE_PASSWORD="$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -dc 'A-Za-z0-9' | cut -c1-24)"
fi
if [[ -z "$KEY_PASSWORD" ]]; then
    KEY_PASSWORD="$STORE_PASSWORD"
fi

if [[ -f "$KEYSTORE_FILE" || -f "$KEY_PROPERTIES_FILE" ]]; then
    echo "Keystore setup already exists:"
    echo "  $KEYSTORE_FILE"
    echo "  $KEY_PROPERTIES_FILE"
    echo "Delete them first if you want to regenerate."
    exit 0
fi

keytool -genkeypair \
    -v \
    -keystore "$KEYSTORE_FILE" \
    -storepass "$STORE_PASSWORD" \
    -alias "$KEY_ALIAS" \
    -keypass "$KEY_PASSWORD" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "$DNAME"

cat >"$KEY_PROPERTIES_FILE" <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$(basename "$KEYSTORE_FILE")
EOF

echo "Created Android release signing files:"
echo "  $KEYSTORE_FILE"
echo "  $KEY_PROPERTIES_FILE"
echo "Back them up before distributing future updates."

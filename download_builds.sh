#!/usr/bin/env bash
set -euo pipefail

REPO="danielsentenac/WaferDb"
WINDOWS_DIR="waferdb_app/windows"
APK_DIR="waferdb_app/build/app/outputs/flutter-apk"
LINUX_DIR="waferdb_app/build/linux/x64/release/bundle"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

latest_run_id() {
  local workflow="$1"
  gh run list --repo "$REPO" --workflow "$workflow" --status success \
    --limit 1 --json databaseId -q '.[0].databaseId'
}

echo "=== Fetching latest successful run IDs ==="
APK_RUN=$(latest_run_id "build-android.yml")
WIN_RUN=$(latest_run_id "build-windows.yml")
LIN_RUN=$(latest_run_id "build-linux.yml")
echo "Android run: $APK_RUN"
echo "Windows run: $WIN_RUN"
echo "Linux   run: $LIN_RUN"

echo ""
echo "=== Downloading artifacts ==="

gh run download "$APK_RUN"  --repo "$REPO" --name "waferdb-android-apk"  --dir "$TMP/apk"
gh run download "$WIN_RUN"  --repo "$REPO" --name "waferdb-windows-setup" --dir "$TMP/win"
gh run download "$LIN_RUN"  --repo "$REPO" --name "waferdb-linux-bundle"  --dir "$TMP/lin"

echo ""
echo "=== Installing ==="

# Android APK
mkdir -p "$APK_DIR"
cp "$TMP/apk/"*.apk "$APK_DIR/app-release.apk"
echo "APK → $APK_DIR/app-release.apk"

# Windows installer
mkdir -p "$WINDOWS_DIR"
EXE=$(find "$TMP/win" -name "*.exe" | head -1)
EXENAME=$(basename "$EXE")
cp "$EXE" "$WINDOWS_DIR/$EXENAME"
echo "EXE → $WINDOWS_DIR/$EXENAME"

# Linux tarball
TARBALL=$(find "$TMP/lin" -name "*.tar.gz" | head -1)
TARNAME=$(basename "$TARBALL")
cp "$TARBALL" "$LINUX_DIR/../../../../../$TARNAME" 2>/dev/null || cp "$TARBALL" "./$TARNAME"
echo "Tarball → $TARNAME"

echo ""
echo "Done."

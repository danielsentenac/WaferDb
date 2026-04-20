#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version>  (e.g. $0 1.1.0)"
  exit 1
}

[[ $# -eq 1 ]] || usage
VERSION="$1"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must be X.Y.Z"; exit 1; }

PUBSPEC="waferdb_app/pubspec.yaml"
CURRENT=$(grep '^version:' "$PUBSPEC" | sed 's/version: *//')
BUILD_NUM=$(echo "$CURRENT" | grep -oP '(?<=\+)\d+' || echo "0")
NEW_BUILD=$(( BUILD_NUM + 1 ))
NEW_VERSION="${VERSION}+${NEW_BUILD}"

echo "Bumping version: $CURRENT → $NEW_VERSION"
sed -i "s/^version: .*/version: $NEW_VERSION/" "$PUBSPEC"

git add "$PUBSPEC"

# Also stage the Linux workflow if it's new/modified
if git status --short .github/workflows/build-linux.yml | grep -q .; then
  git add .github/workflows/build-linux.yml
fi

git commit -m "Bump version to $NEW_VERSION"
git push

echo "Triggering GitHub Actions..."
gh workflow run "Build Android APK"      --ref main
gh workflow run "Build Windows installer" --ref main
gh workflow run "Build Linux bundle"      --ref main

echo ""
echo "Builds triggered for v${VERSION}."
echo "Monitor at: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"

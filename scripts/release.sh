#!/usr/bin/env bash
# Build Linkraptor, package it as a DMG, sign the update for Sparkle and
# publish a GitHub Release. Run from the repo root:
#
#   scripts/release.sh 1.2.0
#
# Needs Xcode, the GitHub CLI (gh) and the Sparkle signing key in your
# Keychain (account "linkraptor", created once with Sparkle's generate_keys).
set -euo pipefail

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: scripts/release.sh <version>   e.g. scripts/release.sh 1.2.0" >&2
    exit 1
fi

REPO="Matmac945/Linkraptor"
TAG="v$VERSION"
APP_NAME="Linkraptor"
BUILD_DIR="build"
OUT_DIR="$BUILD_DIR/release"
# Sparkle compares the build number, so it must grow with every release.
BUILD_NUMBER="$(git rev-list --count HEAD)"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree has uncommitted changes. Commit or stash them first." >&2
    exit 1
fi
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "Release $TAG already exists." >&2
    exit 1
fi

echo "==> Building $APP_NAME $VERSION (build $BUILD_NUMBER)"
xcodebuild -project Linkraptor.xcodeproj -scheme Linkraptor -configuration Release \
    -destination "generic/platform=macOS" -derivedDataPath "$BUILD_DIR" \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    clean build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
SPARKLE_BIN="$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "==> Packaging DMG"
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR/dmg"
ditto "$APP" "$OUT_DIR/dmg/$APP_NAME.app"
ln -s /Applications "$OUT_DIR/dmg/Applications"
DMG="$OUT_DIR/$APP_NAME-$VERSION.dmg"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$OUT_DIR/dmg" -format UDZO -ov "$DMG"
rm -rf "$OUT_DIR/dmg"
# A stable name too, so .../releases/latest/download/Linkraptor.dmg always works.
cp "$DMG" "$OUT_DIR/$APP_NAME.dmg"

echo "==> Generating signed appcast"
mkdir -p "$OUT_DIR/appcast"
cp "$DMG" "$OUT_DIR/appcast/"
"$SPARKLE_BIN/generate_appcast" --account linkraptor \
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
    "$OUT_DIR/appcast"
mv "$OUT_DIR/appcast/appcast.xml" "$OUT_DIR/appcast.xml"
rm -rf "$OUT_DIR/appcast"

echo "==> Publishing GitHub Release $TAG"
gh release create "$TAG" --repo "$REPO" --target "$(git rev-parse HEAD)" \
    --title "$APP_NAME $VERSION" --generate-notes \
    "$DMG" "$OUT_DIR/$APP_NAME.dmg" "$OUT_DIR/appcast.xml"

echo "==> Done: https://github.com/$REPO/releases/tag/$TAG"

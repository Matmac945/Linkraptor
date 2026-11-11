#!/usr/bin/env bash
# Back up or restore Linkraptor's update-signing key (the Sparkle EdDSA key).
#
#   scripts/signing-key.sh backup    # Keychain -> file in the repo (gitignored)
#   scripts/signing-key.sh restore   # file in the repo -> Keychain (e.g. on a new Mac)
set -euo pipefail
cd "$(dirname "$0")/.."

KEY=".secrets/linkraptor-private-key.txt"
TOOL="build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [ ! -x "$TOOL" ]; then
    echo "Downloading Sparkle's tools…"
    xcodebuild -resolvePackageDependencies -project Linkraptor.xcodeproj -scheme Linkraptor -derivedDataPath build >/dev/null
fi

case "${1:-}" in
    backup)
        if [ -e "$KEY" ]; then
            echo "A backup already exists at $KEY. Delete it first if you want a fresh one." >&2
            exit 1
        fi
        umask 077
        mkdir -p -m 700 "$(dirname "$KEY")"
        "$TOOL" --account linkraptor -x "$KEY"
        chmod 600 "$KEY"
        echo "Saved to $KEY (gitignored, never committed)."
        echo "This file only lives on this Mac, so also keep a copy in your password manager."
        ;;
    restore)
        if [ ! -f "$KEY" ]; then
            echo "No backup at $KEY. Copy it there from your password manager first." >&2
            exit 1
        fi
        "$TOOL" --account linkraptor -f "$KEY"
        echo "Key imported into your Keychain. You can now run scripts/release.sh."
        ;;
    *)
        echo "Usage: scripts/signing-key.sh backup|restore" >&2
        exit 1
        ;;
esac

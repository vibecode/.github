#!/usr/bin/env bash
set -euo pipefail

# Install ios-cli into this skill directory.
# Run from anywhere: bash .cursor/skills/build-ios-apps/install-cli.sh

BASE="https://ios.chorus.com"
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"

uname_s="$(uname -s)"
uname_m="$(uname -m)"
case "$uname_s" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  *) echo "ERROR: unsupported OS '$uname_s'." >&2; exit 1 ;;
esac
case "$uname_m" in
  x86_64|amd64) arch="x64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "ERROR: unsupported architecture '$uname_m'." >&2; exit 1 ;;
esac
PLATFORM="$os-$arch"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "ERROR: no sha256 tool found." >&2
    exit 1
  fi
}

echo "[install] platform=$PLATFORM" >&2

MANIFEST="$(curl -fsSL "$BASE/skill/manifest")"
BLOCK="$(printf '%s' "$MANIFEST" | tr ',' '\n' | grep -A2 "\"$PLATFORM\":" || true)"
EXPECTED="$(printf '%s' "$BLOCK" | grep -oE -m1 '[0-9a-f]{64}' || true)"
if ! printf '%s' "$EXPECTED" | grep -qE '^[0-9a-f]{64}$'; then
  echo "ERROR: platform $PLATFORM not found in manifest." >&2
  exit 1
fi

TARBALL="$(mktemp -t ios-cli.XXXXXX)"
trap 'rm -f "$TARBALL"' EXIT
curl -fsSL -o "$TARBALL" "$BASE/skill/download?platform=$PLATFORM"

ACTUAL="$(sha256_of "$TARBALL")"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "ERROR: sha256 mismatch for $PLATFORM." >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -f "$TARBALL"; rm -rf "$TMPDIR"' EXIT
tar -xzf "$TARBALL" -C "$TMPDIR"
cp "$TMPDIR/build-ios-apps/ios-cli" "$SKILL_DIR/ios-cli"
chmod +x "$SKILL_DIR/ios-cli"
echo "[install] installed $SKILL_DIR/ios-cli" >&2

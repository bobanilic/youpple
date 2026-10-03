#!/usr/bin/env bash
# Build the youpple tweak and inject it into a decrypted YouTube IPA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEOS="${THEOS:-$HOME/theos}"
IN="${1:-}"
OUT="${2:-}"

[ -n "$IN" ] || { echo "usage: $0 <decrypted-youtube.ipa> [output.ipa]" >&2; exit 1; }
[ -f "$IN" ] || { echo "IPA not found: $IN" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1 ($2)" >&2; exit 1; }
}

need unzip "install unzip"
need python3 "install Python 3"
need gmake "brew install make"
need dpkg-deb "brew install dpkg"
need ldid "brew install ldid"
need cyan "install cyan/pyzule-rw"

mkdir -p "$ROOT/out"
APP_DIR="$(unzip -Z1 "$IN" | grep -oE '^Payload/[^/]+\.app/' | sort -u | head -1)"
[ -n "$APP_DIR" ] || { echo "No Payload/*.app found in IPA" >&2; exit 1; }

INFO_TMP="$ROOT/out/.youpple-info.plist"
unzip -p "$IN" "${APP_DIR}Info.plist" > "$INFO_TMP"
META="$(python3 - "$INFO_TMP" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as fh:
    p = plistlib.load(fh)
print(p.get('CFBundleIdentifier', 'unknown') + '\t' + p.get('CFBundleShortVersionString', 'unknown'))
PY
)"
rm -f "$INFO_TMP"
IFS=$'\t' read -r BUNDLE_ID YT_VERSION <<< "$META"
MOD_VERSION="$(cat "$ROOT/version.txt" 2>/dev/null || echo 0.0.0)"
OUT="${OUT:-$ROOT/out/youpple-${MOD_VERSION}-yt-${YT_VERSION}.ipa}"

echo "==> youpple $MOD_VERSION"
echo "    YouTube version: $YT_VERSION"
echo "    Bundle ID:       $BUNDLE_ID"
case "$BUNDLE_ID" in
  com.google.ios.youtube|*youtube*) ;;
  *) echo "warning: bundle id does not look like YouTube; continuing because sideload builds can be renamed" >&2 ;;
esac

echo "==> building tweak"
export THEOS
if ! command -v xcrun >/dev/null 2>&1 || ! xcrun -sdk iphoneos --find clang >/dev/null 2>&1; then
  export TARGET_CC=clang TARGET_CXX=clang++ TARGET_LD=clang++ TARGET_STRIP=strip \
         TARGET_LIPO=lipo TARGET_CODESIGN_ALLOCATE=codesign_allocate TARGET_LIBTOOL=libtool
fi
env -u MAKELEVEL gmake -C "$ROOT/tweak" clean package
TWEAK_DEB="$(ls -t "$ROOT"/tweak/packages/*.deb | head -1)"
[ -f "$TWEAK_DEB" ] || { echo "tweak package was not produced" >&2; exit 1; }

echo "==> injecting $TWEAK_DEB"
cyan -i "$IN" -o "$OUT" -f "$TWEAK_DEB" -l "$ROOT/plist/liquid-glass.plist" -s --overwrite

echo "==> done: $OUT"

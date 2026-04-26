#!/usr/bin/env bash
#
# release.sh — end-to-end Developer-ID release pipeline for DontSleep.
#
# Output: dist/DontSleep-<version>.dmg, signed + notarized + stapled.
#
# Prerequisites (set up once; see SIGNING_SETUP.md):
#   - Developer ID Application cert in the login keychain
#   - A notarytool credential profile called "DontSleep"
#
# Optional env overrides:
#   SIGN_IDENTITY       - "Developer ID Application: Your Name (TEAMID)"
#                         (auto-detected if unset)
#   NOTARY_PROFILE      - notarytool profile name (default: DontSleep)
#   BUNDLE_ID           - defaults to com.haru.dontsleep
#   APP_VERSION         - defaults to the CFBundleShortVersionString
#                         from scripts/build_app.sh
#   SKIP_NOTARIZE=1     - sign and staple-skip (produces a locally
#                         usable but Gatekeeper-unverified build)
#   ADHOC=1             - Use "-" (ad-hoc) signing, no notarization.
#                         Fine for your own machine, WILL FAIL Gatekeeper
#                         on other machines.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
cd "$ROOT"

APP_NAME="DontSleep"
BUNDLE_ID="${BUNDLE_ID:-com.haru.dontsleep}"
NOTARY_PROFILE="${NOTARY_PROFILE:-DontSleep}"
APP_VERSION="${APP_VERSION:-0.1.0}"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
ENTITLEMENTS="$ROOT/$APP_NAME.entitlements"
DMG="$DIST/$APP_NAME-$APP_VERSION.dmg"

log() { printf "\033[1;34m>>>\033[0m %s\n" "$*"; }
die() { printf "\033[1;31m!!!\033[0m %s\n" "$*" >&2; exit 1; }

# ---------- 1. Build + bundle ----------
log "build .app bundle"
./scripts/build_app.sh >/dev/null

# ---------- 2. Pick a signing identity ----------
if [ "${ADHOC:-0}" = "1" ]; then
    SIGN_IDENTITY="-"
    log "ad-hoc signing (no notarization)"
elif [ -n "${SIGN_IDENTITY:-}" ]; then
    log "using \$SIGN_IDENTITY: $SIGN_IDENTITY"
else
    SIGN_IDENTITY="$(security find-identity -v -p codesigning \
        | awk -F'"' '/Developer ID Application/ { print $2; exit }' || true)"
    [ -n "$SIGN_IDENTITY" ] \
        || die "no Developer ID Application identity found. Run scripts/release.sh with ADHOC=1, or see SIGNING_SETUP.md"
    log "auto-detected identity: $SIGN_IDENTITY"
fi

# ---------- 3. Codesign ----------
log "codesign"
codesign --force --deep --timestamp \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGN_IDENTITY" \
    "$APP"

log "verify signature"
codesign --verify --verbose=2 "$APP"
spctl --assess --type execute --verbose "$APP" || \
    log "spctl assess failed — expected before notarization"

# ---------- 4. Build the DMG ----------
log "build DMG"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP" \
    -ov -format UDZO \
    "$DMG" >/dev/null

# ---------- 5. Notarize ----------
if [ "${ADHOC:-0}" = "1" ] || [ "${SKIP_NOTARIZE:-0}" = "1" ]; then
    log "skipping notarization (ADHOC=$ADHOC, SKIP_NOTARIZE=${SKIP_NOTARIZE:-0})"
else
    log "submit to notarytool (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$DMG" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    log "staple"
    xcrun stapler staple "$APP"
    xcrun stapler staple "$DMG"

    log "final Gatekeeper assessment"
    spctl --assess --type execute --verbose "$APP"
fi

log "done: $DMG"
ls -lh "$DMG"

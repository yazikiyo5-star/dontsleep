#!/usr/bin/env bash
#
# setup_github_secrets.sh — one-time helper to push the secrets that
# .github/workflows/release.yml needs into GitHub.
#
# Requires:
#   - gh CLI authenticated against the repo owner
#   - dist/DontSleep-keychain.p12 present
#   - $APPLE_APP_SPECIFIC_PASSWORD env var set (the xxxx-xxxx-xxxx-xxxx token)
#   - $APPLE_DEVELOPER_ID_P12_PASSWORD env var set (the .p12 export password)
#
# Usage:
#   APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx \
#   APPLE_DEVELOPER_ID_P12_PASSWORD=dontsleep \
#   ./scripts/setup_github_secrets.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
cd "$ROOT"

REPO="${REPO:-yazikiyo5-star/dontsleep}"
P12="${P12:-dist/DontSleep-keychain.p12}"
APPLE_ID="${APPLE_ID:-haruqvp@icloud.com}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-ZW29TWZK6Q}"

if [ -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
    echo "ERROR: set APPLE_APP_SPECIFIC_PASSWORD env var (xxxx-xxxx-xxxx-xxxx)" >&2
    exit 1
fi
if [ -z "${APPLE_DEVELOPER_ID_P12_PASSWORD:-}" ]; then
    echo "ERROR: set APPLE_DEVELOPER_ID_P12_PASSWORD env var (the .p12 password)" >&2
    exit 1
fi
if [ ! -f "$P12" ]; then
    echo "ERROR: $P12 not found" >&2
    exit 1
fi

echo ">>> setting secrets for $REPO"

P12_B64=$(base64 -i "$P12")

gh secret set APPLE_DEVELOPER_ID_P12_BASE64    --repo "$REPO" --body "$P12_B64"
gh secret set APPLE_DEVELOPER_ID_P12_PASSWORD  --repo "$REPO" --body "$APPLE_DEVELOPER_ID_P12_PASSWORD"
gh secret set APPLE_ID                         --repo "$REPO" --body "$APPLE_ID"
gh secret set APPLE_TEAM_ID                    --repo "$REPO" --body "$APPLE_TEAM_ID"
gh secret set APPLE_APP_SPECIFIC_PASSWORD      --repo "$REPO" --body "$APPLE_APP_SPECIFIC_PASSWORD"

echo
echo "Done. Verify in:"
echo "  https://github.com/$REPO/settings/secrets/actions"
echo
echo "Next time you cut a release, just:"
echo "  git tag v0.2.0 && git push origin v0.2.0"
echo "and the workflow will sign + notarize + upload the DMG automatically."

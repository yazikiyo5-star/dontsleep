# DontSleep — Ad feed

This folder contains a sample `house-ads.sample.json`. You host a real
version of this file **anywhere that serves plain HTTPS JSON**, then paste
the URL into *Preferences → 広告表示 → JSON URL*.

## Recommended hosts (all free)

| Host | Steps |
|---|---|
| **GitHub Pages** | 1. Create a repo (e.g. `dontsleep-ads`)<br>2. Put `house-ads.json` on `main`<br>3. Enable *Settings → Pages → Deploy from branch*<br>4. URL: `https://<user>.github.io/dontsleep-ads/house-ads.json` |
| **Cloudflare Pages** | Drag-drop the folder, get `https://<project>.pages.dev/house-ads.json` |
| **S3 + CloudFront** | Upload + make public, set `Content-Type: application/json` |

## Feed format

Top-level either:
- A JSON array `[{…}, {…}]`, **or**
- `{"ads": [{…}, {…}]}`

Each item:

| Field | Required | Notes |
|---|---|---|
| `id` | ✅ | Stable per creative; used to dedupe impression pings |
| `headline` | ✅ | 1 line, < 60 chars |
| `clickUrl` | ✅ | Where the banner sends the user |
| `attribution` | — | Default `"Sponsored"` |
| `body` | — | Optional subheadline |
| `imageUrl` | — | ≤ 64×64 recommended; falls back to SF Symbol if unreachable |
| `fallbackSymbol` | — | Default `"megaphone.fill"` |
| `impressionUrl` | — | GET'd once per display (first time only); use for your own analytics |
| `weight` | — | Reserved for future weighted rotation; currently ignored |

## Caching

The app fetches the feed once per hour and caches the result. If the fetch
fails, it uses the previous successful result; if there has never been a
successful fetch, it uses the two built-in fallback creatives (self-promo
+ GitHub Sponsors) baked into `HouseAdProvider.swift`.

## Rotation

Creatives are rotated every 60 seconds (round-robin, in feed order).
Impression pings fire **once** per creative id, per app-run.

## Privacy

- No user id, no IP, no UA beyond `DontSleep/0.1`
- If `impressionUrl` is nil, nothing is sent
- `NSWorkspace.shared.open(clickUrl)` handles clicks in the system browser

# Coda Hosted Card (Cards Component)

Internal PE Ops tool for exercising Coda’s **Card Payment Hosted Component** end-to-end without leaving the app.

## Flow

1. **Init** — UI calls Firebase `codaCardInit` → `POST …/Payment/Component/init.json`.
2. **Mount** — Browser loads `coda-card.min.js`, initializes with `clientSecret`, mounts `#payment-form`.
3. **Pay** — Pay enables on `readyStateChange`; `submit()` sends card data to Coda (3DS handled by SDK).
4. **Reconcile** — Primary path uses **inquiry** (`codaCardInquiry`). Frontend SDK success is not final.
5. **Debug panel** — Live backend activity stream (PART G) on the same page.

Authoritative status = inquiry result (`success` / `pending` / `failed`), not the frontend SDK alone.

## Tunable fields (UI)

| Field | Default (example) |
| --- | --- |
| Env | `production` or `sandbox` |
| API key | user-editable |
| Project ID | `31` |
| Country | `485` |
| Currency | `840` |
| Pay type | `421` (card channel) |
| Order / user / item | generated / editable |

Env drives both init and inquiry base URLs together.

## PART F — Optional toggles (off by default)

- **Theme** — edit `appearance.customStyle` JSON in the UI (no code change).
- **Saved cards** — checkboxes + shopper fields; only send when enabled (account must be provisioned; not for IN/ID).
- **Auth & Capture** — stub endpoints `codaCardCapture` / `codaCardCancel` return `501` until enabled.

## PART G — Backend activity / debug panel

Collapsible full-width panel on the Hosted Card page. Polls `codaCardDebugFeed` every 2.5s.

Each entry includes:

- Timestamp (ISO, ms) + correlation / order / txn IDs
- Direction + step (`→ OUTBOUND: Coda init`, …)
- Method + full URL (exposes env/host mismatches)
- Redacted request + response JSON, HTTP status, latency ms
- Interpreted `resultCode` (SUCCESS / PENDING / FAILED)
- Copy request / response / full entry

### Security

- Redacts `apiKey`, merchant secret, `clientSecret` (first/last 4), and card-like digit strings.
- Gate: `CODA_DEBUG_PANEL_ENABLED` (default `true` for this internal tool). Set `false` to hard-disable feed/ingest.
- Optional shared token: `CODA_DEBUG_ACCESS_TOKEN` → require header `X-Coda-Debug-Token`.
- Bounded retention: `CODA_DEBUG_MAX_EVENTS` (default `200`).
- Panel sits behind PE Ops login; do not expose the HTML publicly without auth.

### Observability store

Every Coda call goes through `observedCodaFetch` / `recordDebugEvent` in `functions/src/codaCardObservability.ts`:

- Always writes structured logs (`coda_debug_event`)
- Persists to Firestore `coda_card_debug_events` when available
- Falls back to an in-memory ring buffer if Firestore is unavailable

## Backend endpoints

| Function | Purpose |
| --- | --- |
| `codaCardInit` | Init proxy + debug log |
| `codaCardInquiry` | Inquiry proxy + debug log |
| `codaCardDebugFeed` | GET live events (newest first) |
| `codaCardDebugIngest` | POST frontend lifecycle summaries |
| `codaCardCapture` / `codaCardCancel` | Auth/capture stubs (`501`) |

## Deploy

```bash
cd /Users/nelson/Development/payout-internal-tool

# Enable Firestore in the Firebase console once (Native mode), then:
firebase deploy --only \
  functions:codaCardInit,\
functions:codaCardInquiry,\
functions:codaCardDebugFeed,\
functions:codaCardDebugIngest,\
functions:codaCardCapture,\
functions:codaCardCancel

cd payout_internal_tool
flutter build web --release
cd ..
firebase deploy --only hosting:payout-tool
```

Optional function env:

```bash
firebase functions:config:set coda.debug_panel_enabled="true"
# Prefer params/env in Cloud Console:
# CODA_DEBUG_PANEL_ENABLED=true
# CODA_DEBUG_MAX_EVENTS=200
# CODA_DEBUG_ACCESS_TOKEN=<optional>
```

## Sandbox tip

Switch **Env** to `sandbox` and use a matching sandbox API key/project. Mixing live keys with sandbox URLs (or the reverse) causes charge `400` failures — the debug panel URL column makes that obvious.

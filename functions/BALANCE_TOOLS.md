# Check Balance + Balance Update (Cloud Functions)

Migrated from the internal Python CLI. JWT signing, SMTP, and outbound payout
calls run **only** in Firebase Cloud Functions.

## Endpoints

| Function | Method | URL |
|----------|--------|-----|
| `checkBalance` | POST | `https://us-central1-codapay-webhook.cloudfunctions.net/checkBalance` |
| `balanceUpdate` | POST | `https://us-central1-codapay-webhook.cloudfunctions.net/balanceUpdate` |

### `checkBalance` body
```json
{
  "secret": "...",
  "partner_id": "...",
  "api_key": "...",
  "production": false
}
```

### `balanceUpdate` body
```json
{
  "secret": "...",
  "partner_id": "...",
  "api_key": "...",
  "balance_value": 80,
  "currency": "USD",
  "credit_limit": 1000
}
```

**Payout Balance offset (intentional):** if `balance_value < 100` → `-(100 - value)`, else `+(value - 100)`.

## Secrets / env (Firebase)

```bash
# Existing
firebase functions:secrets:set EMAIL_APP_PASSWORD

# New — AES zip password (rotate away from legacy CLI default)
firebase functions:secrets:set BALANCE_ZIP_PASSWORD

# Optional params (firebase functions:config or params)
# SMTP_USER=nelson.wong@codapayments.com
# BALANCE_EMAIL_TO=payout-qa-internal@codapayments.com
# BALANCE_EMAIL_CC=codapay_integration@codapayments.com
# BALANCE_SCHEDULER_URL=https://payout-scheduler.codapay.net/internal/scheduler/email-workflow/check-new-email
```

Set `SMTP_USER` when deploying (Functions params):

```bash
firebase functions:config:set  # or use defineString defaults at deploy prompts
```

With `defineString`, set via:

```bash
firebase deploy --only functions:checkBalance,functions:balanceUpdate
# CLI will prompt for unset params, or pass:
# firebase functions:secrets:access ...
```

## Deploy

```bash
cd functions
npm run build
cd ..
firebase deploy --only functions:checkBalance,functions:balanceUpdate
```

Scheduler ping may require the Functions runtime network path that can reach
`payout-scheduler.codapay.net` (same constraint as renotify / VPN-era tools).

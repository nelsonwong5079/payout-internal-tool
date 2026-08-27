# Hosted Card client accounts

External clients can sign in to [https://payout-tool.web.app/](https://payout-tool.web.app/)
with a dedicated Firebase Auth user and **only** see the Hosted Card tool
(no other PE Ops modules, no internal API key presets, no debug/guide panels).

## Create a client user

1. Firebase Console → project **`codapay-webhook`** → **Authentication** → **Users** → **Add user**.
2. Create an email/password account, e.g. `hosted-card.client@codapayments.com`.
3. Add that **exact email** (lowercase) to `kHostedCardClientEmails` in:

   `payout_internal_tool/lib/services/app_access.dart`

4. Rebuild + deploy hosting:

```bash
cd payout_internal_tool && flutter build web --release && cd ..
firebase deploy --only hosting:payout-tool
```

## What clients see

- Login → Hosted Card shell only (no sidebar modules).
- Hosted Card iframe loads with `?audience=client`:
  - No ops guide (contains internal keys).
  - No backend debug panel / SDK diagnostics.
  - No pre-filled API keys / project IDs (they enter their own).
- Your staff account (`nelson.wong@…` etc.) stays full **OPERATOR** access.

## Notes

- Access control is by email allowlist (not Firebase custom claims yet).
- Cloud Function URLs remain callable if someone has them; this gates the **UI**.
  Tighten Functions with Firebase Auth later if needed.

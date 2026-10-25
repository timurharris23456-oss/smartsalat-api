# Enabling push notifications (the "nudge" feature)

All the nudge code is built and verified. Actual push **delivery** needs a
one-time setup that can only be done in the Apple Developer account (Roya Qaemi)
and on Render — until then, nudges are still recorded and de-duplicated, they
just don't deliver a notification (`/nudge` returns `"delivered": 0`).

## 1. Turn on the capability in Xcode
Open the project → select the **salattracker** target → **Signing & Capabilities**
→ **+ Capability** → **Push Notifications**. With automatic signing this registers
push with the App ID and adds the `aps-environment` entitlement. Rebuild.

## 2. Create an APNs auth key (.p8)
At [developer.apple.com](https://developer.apple.com/account) →
**Certificates, Identifiers & Profiles → Keys → +** → check
**Apple Push Notifications service (APNs)** → Continue → Register → **Download**
the `.p8` (you can only download it once). Note three things:
- **Key ID** — shown on the key's page
- **Team ID** — top-right of the developer portal
- **Bundle ID** — `timurmirabi.salattracker`

## 3. Set the environment variables on Render
`smartsalat-api` service → **Environment**:
| Key | Value |
|-----|-------|
| `APNS_KEY` | the full contents of the `.p8` file (include the `BEGIN/END` lines; real newlines or `\n` escapes both work) |
| `APNS_KEY_ID` | your Key ID |
| `APNS_TEAM_ID` | your Team ID |
| `APNS_HOST` *(optional)* | `https://api.sandbox.push.apple.com` while testing debug builds on a device; leave unset (production) for TestFlight/App Store |
| `APNS_BUNDLE_ID` *(optional)* | defaults to `timurmirabi.salattracker` |

Redeploy. `/nudge` will then return `"delivered" > 0` when the recipient has the
app installed with notifications allowed.

## Notes
- **Debug builds run from Xcode register with the SANDBOX APNs environment** — set
  `APNS_HOST` to the sandbox URL to test on your device. TestFlight/App Store
  builds use production (the default).
- The backend caches the APNs auth JWT (<1h) and automatically prunes device
  tokens that APNs reports as dead (BadDeviceToken / Unregistered).
- The app uploads its device token via `POST /device-token` after sign-in, once
  the user allows notifications.

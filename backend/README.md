# SmartSalat API

Username/password accounts + per-account prayer-record sync, backed by MongoDB.
This is what makes "log in anywhere and your data is there" work — accounts and
records live on the server, not the phone.

## Endpoints
| Method | Path        | Auth   | Purpose                                  |
|--------|-------------|--------|------------------------------------------|
| POST   | `/register` | —      | Create an account (bcrypt-hashed password) |
| POST   | `/login`    | —      | Returns a bearer `token`                 |
| POST   | `/logout`   | Bearer | Invalidates the current session          |
| GET    | `/records`  | Bearer | The account's prayer records             |
| PUT    | `/records`  | Bearer | Upsert the account's records             |
| GET    | `/health`   | —      | Liveness check                           |

Collections used in the `smartsalat` DB: `users`, `sessions`, `prayer_records`.

## Run locally (for the iOS Simulator)

```bash
cd backend
pip3 install -r requirements.txt
export MONGODB_URI="mongodb+srv://USER:PASS@cluster.xxxx.mongodb.net"
uvicorn app:app --host 0.0.0.0 --port 8000
```

The iOS Simulator reaches this at `http://localhost:8000` (already configured in
the app's `APIClient`).

## For a real device / production
- **Deploy** it (Render, Railway, Fly.io) and point the app's `APIClient.baseURL`
  at the HTTPS URL.
- Add the host's IP to Atlas → Network Access.
- Hardening still to do: HTTPS/TLS (required off-simulator), token expiry,
  rate-limiting on `/login`, and storing the app's token in the Keychain
  (currently UserDefaults for the demo).

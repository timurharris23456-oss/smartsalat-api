# Deploying the SmartSalat API (so it works on real phones)

The app on a phone can't reach `localhost` — the server has to be on the public
internet with an HTTPS URL. Deploy once, then put that URL in the app.

## Step 1 — Open MongoDB Atlas to your host
Atlas → **Network Access** → Add IP Address → **Allow from anywhere** (`0.0.0.0/0`).
Hosts use rotating IPs, so this is the practical option — just keep a **strong DB
password** (and rotate the one currently exposed in chat).

## Step 2 — Deploy the backend

Pick one. All three give you an HTTPS URL like `https://smartsalat-api.onrender.com`.

### Option A — Render (via GitHub, most guided)
1. Push the `backend/` folder to a GitHub repo.
2. Render → **New → Blueprint**, select the repo (it reads `render.yaml`).
3. When prompted, set the **`MONGODB_URI`** env var to your Atlas string.
4. Deploy → copy the resulting `https://…onrender.com` URL.

### Option B — Railway (deploy local code, no GitHub needed)
```bash
cd backend
npm i -g @railway/cli && railway login
railway init && railway up
railway variables set MONGODB_URI="mongodb+srv://…"
railway domain            # gives you the public HTTPS URL
```

### Option C — Fly.io (local Docker, no GitHub needed)
```bash
cd backend
fly launch --no-deploy            # uses the Dockerfile
fly secrets set MONGODB_URI="mongodb+srv://…"
fly deploy
```

## Step 3 — Point the app at it
In Xcode open **salattracker/Info.plist**, set **`APIBaseURL`** to your deployed
HTTPS URL, e.g. `https://smartsalat-api.onrender.com`. Rebuild — login now works
on the phone *and* the simulator.

## Step 4 — Verify
```bash
curl https://YOUR-URL/health          # -> {"ok":true}
```

## Notes
- Free tiers (Render) sleep when idle, so the first request after a while takes a
  few seconds to wake — fine for a personal app.
- With a real HTTPS URL you no longer depend on the `NSAllowsLocalNetworking`
  exception; it's kept only so `localhost` still works in the simulator.

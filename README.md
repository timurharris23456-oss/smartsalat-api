# SmartSalat

A prayer-tracking iOS app: mark daily prayers, prayer times & Qibla for your
location, an Ayah of the day, prayer-time notifications, and social streaks with
friends. This repository is a monorepo containing the app, its backend, and a
data pipeline.

## Structure

| Folder | What it is |
|---|---|
| `salattracker/` | The SwiftUI iOS app (Xcode project). |
| `backend/` | FastAPI + MongoDB server — accounts, per-account prayer-record sync, and friends. Deployed on Render. |
| `etl/` | A Python ETL that extracts prayer records and loads them into MongoDB. |

## iOS app

Open `salattracker/salattracker.xcodeproj` in Xcode and run. The app talks to the
backend URL in `salattracker/salattracker/Info.plist` (`APIBaseURL`).

## Backend

See [`backend/README.md`](backend/README.md) and [`backend/DEPLOY.md`](backend/DEPLOY.md).
Render deploys from the `backend/` subfolder (configured via `render.yaml`
`rootDir: backend`). It needs a `MONGODB_URI` environment variable.

## ETL

See [`etl/README.md`](etl/README.md).

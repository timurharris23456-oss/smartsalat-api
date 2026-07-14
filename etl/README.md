# SmartSalat → MongoDB ETL

A small, idempotent pipeline that moves SmartSalat prayer records into MongoDB.

- **Extract** — from a JSON export, or straight from a booted iOS Simulator's
  `UserDefaults`.
- **Transform** — one clean document per user-day, plus a per-user summary
  (current streak, days prayed, perfect days, total prayers).
- **Load** — upsert into MongoDB keyed on a deterministic `_id` (`userId:date`),
  so re-running updates rows instead of duplicating them.

## 1. Install

```bash
cd etl
pip3 install -r requirements.txt
```

## 2. Point it at MongoDB

Create a free **MongoDB Atlas** M0 cluster (or use any Mongo), then grab the
connection string and set it as an env var:

```bash
export MONGODB_URI="mongodb+srv://USER:PASS@cluster.xxxx.mongodb.net"
export MONGODB_DB="smartsalat"            # optional (default: smartsalat)
export MONGODB_COLLECTION="prayer_records" # optional
```

> Never hard-code the URI in the iOS app — only this backend pipeline holds it.

## 3. Run

Preview the transform without writing anything:

```bash
python3 etl.py --input records.sample.json --user timur --dry-run
```

Extract from the running simulator and load to Mongo:

```bash
python3 etl.py --from-simulator --user timur
```

Or from a JSON export:

```bash
python3 etl.py --input records.sample.json --user timur
```

## Document shape

`prayer_records` collection, one per user-day:

```json
{
  "_id": "timur:2026-07-06",
  "userId": "timur",
  "date": "2026-07-06",
  "dateUTC": "2026-07-06T00:00:00Z",
  "fard": ["asr"],
  "sunnah": ["fajr"],
  "witr": true,
  "prayedCount": 1,
  "complete": false,
  "countsForStreak": true,
  "source": "smartsalat-ios",
  "updatedAt": "…"
}
```

`user_stats` collection, one per user:

```json
{
  "_id": "timur",
  "userId": "timur",
  "currentStreak": 3,
  "daysTracked": 3,
  "daysPrayed": 3,
  "perfectDays": 0,
  "totalFardPrayers": 3,
  "updatedAt": "…"
}
```

## Where this fits

The iOS app can't talk to MongoDB directly (that would leak DB credentials).
This pipeline is the backend side: today it runs on demand against a JSON
export or the simulator. To make it live, have the app POST its records to a
small HTTPS API that calls the same `transform` + `load` steps — or schedule
this script (cron / a hosted job) against exported data.

## Extend it

- **Scheduled runs**: wrap in cron, an Atlas Scheduled Trigger, or a hosted job.
- **Multiple users**: pass a different `--user`, or loop over exports.
- **Analytics**: add aggregation-pipeline stages in `transform` to build
  reporting collections (weekly completion rates, cohort retention, etc.).

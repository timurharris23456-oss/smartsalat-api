#!/usr/bin/env python3
"""
SmartSalat ETL — Extract prayer records, Transform to documents, Load to MongoDB.

  Extract   from a JSON export, or directly from a booted iOS Simulator.
  Transform each day into a clean document + compute a per-user summary.
  Load      idempotent upsert into MongoDB (safe to re-run any number of times).

Config comes from env vars (CLI flags override):
  MONGODB_URI          e.g. mongodb+srv://user:pass@cluster.mongodb.net
  MONGODB_DB           default: smartsalat
  MONGODB_COLLECTION   default: prayer_records
  USER_ID              default: local-user

Examples:
  # Preview the documents without touching MongoDB:
  python etl.py --input records.sample.json --user timur --dry-run

  # Pull straight from the running simulator and load to Atlas:
  MONGODB_URI="mongodb+srv://…" python etl.py --from-simulator --user timur
"""

import argparse
import json
import os
import plistlib
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone

PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"]


# ------------------------------------------------------------------ Extract

def extract_from_json(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def extract_from_simulator(bundle_id: str) -> dict:
    """Read the app's `prayerRecords` out of the booted simulator's UserDefaults."""
    container = subprocess.check_output(
        ["xcrun", "simctl", "get_app_container", "booted", bundle_id, "data"],
        text=True,
    ).strip()
    plist_path = os.path.join(container, "Library", "Preferences", f"{bundle_id}.plist")
    with open(plist_path, "rb") as f:
        prefs = plistlib.load(f)
    blob = prefs.get("prayerRecords")
    if not blob:
        return {}
    if isinstance(blob, (bytes, bytearray)):
        blob = blob.decode("utf-8")
    return json.loads(blob)


# ---------------------------------------------------------------- Transform

def to_document(user_id: str, day: str, record: dict) -> dict:
    fard = [p for p in PRAYERS if p in set(record.get("fard", []))]
    sunnah = [p for p in PRAYERS if p in set(record.get("sunnah", []))]
    return {
        "_id": f"{user_id}:{day}",              # deterministic → idempotent upserts
        "userId": user_id,
        "date": day,
        "dateUTC": datetime.strptime(day, "%Y-%m-%d").replace(tzinfo=timezone.utc),
        "fard": fard,
        "sunnah": sunnah,
        "witr": bool(record.get("witr", False)),
        "prayedCount": len(fard),
        "complete": len(fard) == len(PRAYERS),
        "countsForStreak": len(fard) >= 1,
        "source": "smartsalat-ios",
        "updatedAt": datetime.now(timezone.utc),
    }


def current_streak(records: dict) -> int:
    """Consecutive days ending today with >=1 fard prayer (mirrors the app)."""
    counting = {d for d, r in records.items() if len(r.get("fard", [])) >= 1}
    day = date.today()
    if day.isoformat() not in counting:
        day -= timedelta(days=1)          # an untouched today doesn't break the run
    streak = 0
    while day.isoformat() in counting:
        streak += 1
        day -= timedelta(days=1)
    return streak


def to_summary(user_id: str, records: dict, docs: list) -> dict:
    return {
        "_id": user_id,
        "userId": user_id,
        "currentStreak": current_streak(records),
        "daysTracked": len(records),
        "daysPrayed": sum(1 for r in records.values() if len(r.get("fard", [])) >= 1),
        "perfectDays": sum(1 for d in docs if d["complete"]),
        "totalFardPrayers": sum(len(r.get("fard", [])) for r in records.values()),
        "updatedAt": datetime.now(timezone.utc),
    }


def transform(user_id: str, records: dict):
    docs = [to_document(user_id, day, rec) for day, rec in sorted(records.items())]
    return docs, to_summary(user_id, records, docs)


# --------------------------------------------------------------------- Load

def load(docs: list, summary: dict, uri: str, db_name: str, coll_name: str) -> None:
    from pymongo import MongoClient, ReplaceOne

    client = MongoClient(uri)
    try:
        db = client[db_name]
        if docs:
            db[coll_name].bulk_write(
                [ReplaceOne({"_id": d["_id"]}, d, upsert=True) for d in docs],
                ordered=False,
            )
        db["user_stats"].replace_one({"_id": summary["_id"]}, summary, upsert=True)
    finally:
        client.close()


# --------------------------------------------------------------------- Main

def main() -> int:
    parser = argparse.ArgumentParser(description="SmartSalat → MongoDB ETL")
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--input", help="Path to a records JSON export")
    src.add_argument("--from-simulator", action="store_true",
                     help="Extract from the booted iOS simulator")
    parser.add_argument("--bundle-id", default="timurmirabi.salattracker")
    parser.add_argument("--user", default=os.environ.get("USER_ID", "local-user"))
    parser.add_argument("--uri", default=os.environ.get("MONGODB_URI"))
    parser.add_argument("--db", default=os.environ.get("MONGODB_DB", "smartsalat"))
    parser.add_argument("--collection",
                        default=os.environ.get("MONGODB_COLLECTION", "prayer_records"))
    parser.add_argument("--dry-run", action="store_true",
                        help="Print the transformed documents; skip loading")
    args = parser.parse_args()

    # Extract
    records = (extract_from_json(args.input) if args.input
               else extract_from_simulator(args.bundle_id))
    print(f"[extract] {len(records)} day(s) from "
          f"{'simulator' if args.from_simulator else args.input}", file=sys.stderr)

    # Transform
    docs, summary = transform(args.user, records)
    print(f"[transform] {len(docs)} document(s); "
          f"currentStreak={summary['currentStreak']}", file=sys.stderr)

    if args.dry_run or not args.uri:
        if not args.uri and not args.dry_run:
            print("[load] no MONGODB_URI set — printing instead of loading.", file=sys.stderr)
        print(json.dumps({"documents": docs, "summary": summary}, default=str, indent=2))
        return 0

    # Load
    load(docs, summary, args.uri, args.db, args.collection)
    print(f"[load] upserted {len(docs)} record(s) + summary into "
          f"{args.db}.{args.collection}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

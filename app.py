"""
SmartSalat API — username/password accounts + per-account prayer-record sync,
backed by MongoDB. Passwords are stored as bcrypt hashes; sessions are opaque
bearer tokens.

Run:
  export MONGODB_URI="mongodb+srv://…"
  uvicorn app:app --host 0.0.0.0 --port 8000
"""

import os
import secrets
from datetime import datetime, timezone

import bcrypt
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel
from pymongo import MongoClient, ReplaceOne

PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"]

client = MongoClient(os.environ["MONGODB_URI"])
db = client[os.environ.get("MONGODB_DB", "smartsalat")]
users = db["users"]
sessions = db["sessions"]
records_col = db["prayer_records"]

app = FastAPI(title="SmartSalat API")


class Credentials(BaseModel):
    username: str
    password: str


class Day(BaseModel):
    fard: list[str] = []
    sunnah: list[str] = []
    witr: bool = False


class RecordsBody(BaseModel):
    records: dict[str, Day]


def current_user(authorization: str = Header(default="")) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not signed in")
    token = authorization.split(" ", 1)[1]
    session = sessions.find_one({"_id": token})
    if not session:
        raise HTTPException(status_code=401, detail="Session expired — sign in again")
    return session["username"]


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/register", status_code=201)
def register(creds: Credentials):
    username = creds.username.strip().lower()
    if len(username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters")
    if len(creds.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    if users.find_one({"_id": username}):
        raise HTTPException(status_code=409, detail="That username is taken")
    users.insert_one({
        "_id": username,
        "passwordHash": bcrypt.hashpw(creds.password.encode(), bcrypt.gensalt()),
        "createdAt": datetime.now(timezone.utc),
    })
    return {"username": username}


@app.post("/login")
def login(creds: Credentials):
    username = creds.username.strip().lower()
    user = users.find_one({"_id": username})
    if not user or not bcrypt.checkpw(creds.password.encode(), user["passwordHash"]):
        raise HTTPException(status_code=401, detail="Wrong username or password")
    token = secrets.token_urlsafe(24)
    sessions.insert_one({
        "_id": token,
        "username": username,
        "createdAt": datetime.now(timezone.utc),
    })
    return {"token": token, "username": username}


@app.post("/logout", status_code=204)
def logout(authorization: str = Header(default="")):
    if authorization.startswith("Bearer "):
        sessions.delete_one({"_id": authorization.split(" ", 1)[1]})
    return None


@app.get("/records")
def get_records(username: str = Depends(current_user)):
    out: dict[str, dict] = {}
    for doc in records_col.find({"userId": username}):
        out[doc["date"]] = {
            "fard": doc.get("fard", []),
            "sunnah": doc.get("sunnah", []),
            "witr": doc.get("witr", False),
        }
    return {"records": out}


@app.put("/records")
def put_records(body: RecordsBody, username: str = Depends(current_user)):
    ops = []
    for day, rec in body.records.items():
        fard = [p for p in PRAYERS if p in set(rec.fard)]
        sunnah = [p for p in PRAYERS if p in set(rec.sunnah)]
        doc = {
            "_id": f"{username}:{day}",
            "userId": username,
            "date": day,
            "fard": fard,
            "sunnah": sunnah,
            "witr": rec.witr,
            "prayedCount": len(fard),
            "complete": len(fard) == len(PRAYERS),
            "countsForStreak": len(fard) >= 1,
            "updatedAt": datetime.now(timezone.utc),
        }
        ops.append(ReplaceOne({"_id": doc["_id"]}, doc, upsert=True))
    if ops:
        records_col.bulk_write(ops, ordered=False)
    return {"saved": len(ops)}

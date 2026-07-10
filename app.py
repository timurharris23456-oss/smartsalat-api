"""
SmartSalat API — username/password accounts, per-account prayer-record sync, and
friends (via a unique 6-digit friend code). Passwords are bcrypt-hashed; sessions
are opaque bearer tokens. Backed by MongoDB.

Run:
  export MONGODB_URI="mongodb+srv://…"
  uvicorn app:app --host 0.0.0.0 --port 8000
"""

import os
import random
import secrets
from datetime import date, datetime, timedelta, timezone

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

# Friend codes must be unique among users that have one.
users.create_index(
    "friendCode",
    unique=True,
    partialFilterExpression={"friendCode": {"$type": "string"}},
)

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


class AddFriendBody(BaseModel):
    code: str


class RespondBody(BaseModel):
    username: str


# ------------------------------------------------------------------ Helpers

def current_user(authorization: str = Header(default="")) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not signed in")
    token = authorization.split(" ", 1)[1]
    session = sessions.find_one({"_id": token})
    if not session:
        raise HTTPException(status_code=401, detail="Session expired — sign in again")
    return session["username"]


def new_friend_code() -> str:
    """A 6-digit code (100000–999999) not already assigned to another user."""
    for _ in range(25):
        code = str(random.randint(100000, 999999))
        if not users.find_one({"friendCode": code}):
            return code
    raise HTTPException(status_code=500, detail="Could not allocate a friend code")


def streak_from_records(day_records: dict) -> int:
    """Consecutive days ending today with >=1 fard prayer."""
    counting = {d for d, r in day_records.items() if len(r.get("fard", [])) >= 1}
    day = date.today()
    if day.isoformat() not in counting:
        day -= timedelta(days=1)
    streak = 0
    while day.isoformat() in counting:
        streak += 1
        day -= timedelta(days=1)
    return streak


# --------------------------------------------------------------------- Auth

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
    friend_code = new_friend_code()
    users.insert_one({
        "_id": username,
        "passwordHash": bcrypt.hashpw(creds.password.encode(), bcrypt.gensalt()),
        "friendCode": friend_code,
        "friends": [],
        "createdAt": datetime.now(timezone.utc),
    })
    return {"username": username, "friendCode": friend_code}


@app.post("/login")
def login(creds: Credentials):
    username = creds.username.strip().lower()
    user = users.find_one({"_id": username})
    if not user or not bcrypt.checkpw(creds.password.encode(), user["passwordHash"]):
        raise HTTPException(status_code=401, detail="Wrong username or password")
    # Backfill a friend code for accounts created before codes existed.
    friend_code = user.get("friendCode")
    if not friend_code:
        friend_code = new_friend_code()
        users.update_one({"_id": username}, {"$set": {"friendCode": friend_code}})
    token = secrets.token_urlsafe(24)
    sessions.insert_one({
        "_id": token,
        "username": username,
        "createdAt": datetime.now(timezone.utc),
    })
    return {"token": token, "username": username, "friendCode": friend_code}


@app.post("/logout", status_code=204)
def logout(authorization: str = Header(default="")):
    if authorization.startswith("Bearer "):
        sessions.delete_one({"_id": authorization.split(" ", 1)[1]})
    return None


@app.get("/me")
def me(username: str = Depends(current_user)):
    user = users.find_one({"_id": username}) or {}
    return {"username": username, "friendCode": user.get("friendCode", "")}


# ------------------------------------------------------------------ Records

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


# ------------------------------------------------------------------ Friends

@app.post("/friends/add")
def add_friend(body: AddFriendBody, username: str = Depends(current_user)):
    """Send a friend request (the recipient must accept)."""
    code = body.code.strip()
    target = users.find_one({"friendCode": code})
    if not target:
        raise HTTPException(status_code=404, detail="No one has that friend code")
    tname = target["_id"]
    if tname == username:
        raise HTTPException(status_code=400, detail="That's your own code")
    me_doc = users.find_one({"_id": username}) or {}
    if tname in me_doc.get("friends", []):
        raise HTTPException(status_code=400, detail="You're already friends")
    if username in target.get("incomingRequests", []):
        raise HTTPException(status_code=400, detail="Request already sent")
    users.update_one({"_id": tname}, {"$addToSet": {"incomingRequests": username}})
    return {"requested": tname}


@app.get("/friends/requests")
def friend_requests(username: str = Depends(current_user)):
    """Usernames of people who have requested to be your friend."""
    user = users.find_one({"_id": username}) or {}
    return {"requests": user.get("incomingRequests", [])}


@app.post("/friends/accept")
def accept_friend(body: RespondBody, username: str = Depends(current_user)):
    requester = body.username.strip().lower()
    user = users.find_one({"_id": username}) or {}
    if requester not in user.get("incomingRequests", []):
        raise HTTPException(status_code=404, detail="No such friend request")
    users.update_one(
        {"_id": username},
        {"$pull": {"incomingRequests": requester}, "$addToSet": {"friends": requester}},
    )
    users.update_one({"_id": requester}, {"$addToSet": {"friends": username}})
    return {"accepted": requester}


@app.post("/friends/decline")
def decline_friend(body: RespondBody, username: str = Depends(current_user)):
    requester = body.username.strip().lower()
    users.update_one({"_id": username}, {"$pull": {"incomingRequests": requester}})
    return {"declined": requester}


@app.get("/friends")
def list_friends(username: str = Depends(current_user)):
    user = users.find_one({"_id": username}) or {}
    friend_names = user.get("friends", [])
    if not friend_names:
        return {"friends": []}

    by_user: dict[str, dict] = {}
    for rec in records_col.find({"userId": {"$in": friend_names}}):
        by_user.setdefault(rec["userId"], {})[rec["date"]] = rec

    today = date.today().isoformat()
    friends = []
    for name in friend_names:
        day_records = by_user.get(name, {})
        friends.append({
            "username": name,
            "streak": streak_from_records(day_records),
            "completedToday": day_records.get(today, {}).get("fard", []),
        })
    friends.sort(key=lambda f: f["streak"], reverse=True)
    return {"friends": friends}

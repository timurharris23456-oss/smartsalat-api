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
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from pymongo import MongoClient, ReplaceOne

SUPPORT_EMAIL = "timurharris23456@gmail.com"

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
    tzOffset: int = 0   # the client's minutes-from-UTC, so "today" is computed in the user's local time


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
    """A random 6-digit code not already assigned to another user."""
    for _ in range(25):
        code = str(random.randint(100000, 999999))
        if not users.find_one({"friendCode": code}):
            return code
    raise HTTPException(status_code=500, detail="Could not allocate a friend code")


def local_today(tz_offset_minutes: int):
    """The user's current local date, given their minutes-from-UTC offset."""
    return (datetime.now(timezone.utc) + timedelta(minutes=tz_offset_minutes)).date()


def streak_from_records(day_records: dict, today) -> int:
    """Consecutive days ending on `today` (the user's local date) with >=1 fard."""
    counting = {d for d, r in day_records.items() if len(r.get("fard", [])) >= 1}
    day = today
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
    return {"ok": True, "version": "3-support"}


SUPPORT_PAGE = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SmartSalat — Support</title>
<style>
  :root {{ color-scheme: light dark; }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; padding: 2.5rem 1.25rem;
    font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: #1c1c1e; background: #f7f7f8;
    display: flex; justify-content: center;
  }}
  .wrap {{ max-width: 640px; width: 100%; }}
  h1 {{ font-size: 1.9rem; margin: 0 0 .25rem; }}
  .sub {{ color: #6b6b70; margin: 0 0 2rem; }}
  h2 {{ font-size: 1.15rem; margin: 2rem 0 .5rem; }}
  a {{ color: #1c7c54; }}
  .card {{
    background: #fff; border: 1px solid #e5e5e7; border-radius: 14px;
    padding: 1.1rem 1.25rem; margin: 1rem 0;
  }}
  .q {{ font-weight: 600; margin: 1rem 0 .2rem; }}
  .q:first-child {{ margin-top: 0; }}
  footer {{ color: #9a9a9f; font-size: .85rem; margin-top: 2.5rem; }}
  @media (prefers-color-scheme: dark) {{
    body {{ color: #ececf0; background: #0f0f10; }}
    .sub {{ color: #9a9a9f; }}
    .card {{ background: #1b1b1d; border-color: #2c2c2e; }}
    a {{ color: #57d9a3; }}
  }}
</style>
</head>
<body>
  <div class="wrap">
    <h1>SmartSalat Support</h1>
    <p class="sub">Track your daily prayers, prayer times, Qibla, and streaks with friends.</p>

    <div class="card">
      <p style="margin:0 0 .4rem"><strong>Need help?</strong> Email us and we'll get back to you, usually within 2&ndash;3 days.</p>
      <p style="margin:0"><a href="mailto:{SUPPORT_EMAIL}?subject=SmartSalat%20Support">{SUPPORT_EMAIL}</a></p>
    </div>

    <h2>Frequently asked questions</h2>
    <div class="card">
      <p class="q">How do I mark a prayer as prayed?</p>
      <p style="margin:0">On the home screen, tap a prayer to mark it complete. Your streak counts any day you pray at least one fard prayer.</p>

      <p class="q">Why don't my prayer times match another app?</p>
      <p style="margin:0">Times are calculated from your device's location. Make sure location access is enabled in Settings so the app can pinpoint your area.</p>

      <p class="q">How do I add a friend?</p>
      <p style="margin:0">Open Settings to find your friend code, share it, and enter a friend's code to send them a request. They accept, and you'll see each other's streaks.</p>

      <p class="q">Is my data private?</p>
      <p style="margin:0">Yes. We collect only what's needed to sync your account and connect you with friends you choose. The full privacy policy is available inside the app.</p>
    </div>

    <footer>SmartSalat &middot; Contact: {SUPPORT_EMAIL}</footer>
  </div>
</body>
</html>"""


@app.get("/support", response_class=HTMLResponse)
def support():
    return SUPPORT_PAGE


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
        "tzOffset": creds.tzOffset,
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
    # Keep the user's timezone offset current so friend "today" is accurate.
    users.update_one({"_id": username}, {"$set": {"tzOffset": creds.tzOffset}})
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

    # Each friend's "today" is computed in their own timezone.
    friend_docs = {u["_id"]: u for u in users.find({"_id": {"$in": friend_names}})}

    friends = []
    for name in friend_names:
        day_records = by_user.get(name, {})
        today = local_today(friend_docs.get(name, {}).get("tzOffset", 0))
        friends.append({
            "username": name,
            "streak": streak_from_records(day_records, today),
            "completedToday": day_records.get(today.isoformat(), {}).get("fard", []),
        })
    friends.sort(key=lambda f: f["streak"], reverse=True)
    return {"friends": friends}

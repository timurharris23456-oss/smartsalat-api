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
import time
from collections import defaultdict, deque
from datetime import date, datetime, timedelta, timezone

import bcrypt
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from pymongo import MongoClient, ReplaceOne

SUPPORT_EMAIL = "timurharris23456@gmail.com"
OPERATOR_NAME = "Roya Qaemi"
SESSION_TTL_DAYS = 180

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
# Bearer tokens expire so a leaked session can't be used forever.
sessions.create_index("createdAt", expireAfterSeconds=SESSION_TTL_DAYS * 24 * 60 * 60)

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

# In-memory sliding-window rate limiting. Per-process, which is fine for the
# single free-tier instance; it fails open for clients we can't identify.
_rate_buckets: dict[str, deque] = defaultdict(deque)


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def rate_limit(request: Request, name: str, max_hits: int, window_secs: int) -> None:
    ip = _client_ip(request)
    if ip == "unknown":
        return
    key = f"{name}:{ip}"
    now = time.monotonic()
    bucket = _rate_buckets[key]
    while bucket and bucket[0] <= now - window_secs:
        bucket.popleft()
    if len(bucket) >= max_hits:
        raise HTTPException(status_code=429, detail="Too many attempts — please wait a minute and try again.")
    bucket.append(now)


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
    return {"ok": True, "version": "4-account"}


# ------------------------------------------------------------- Public pages

_PAGE_CSS = """
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 2.5rem 1.25rem;
    font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: #1c1c1e; background: #f7f7f8;
    display: flex; justify-content: center;
  }
  .wrap { max-width: 640px; width: 100%; }
  h1 { font-size: 1.9rem; margin: 0 0 .25rem; }
  .sub { color: #6b6b70; margin: 0 0 2rem; }
  h2 { font-size: 1.15rem; margin: 2rem 0 .5rem; }
  a { color: #1c7c54; }
  .card { background: #fff; border: 1px solid #e5e5e7; border-radius: 14px; padding: 1.1rem 1.25rem; margin: 1rem 0; }
  .card ul { margin: 0; padding-left: 1.2rem; }
  .card li { margin: .35rem 0; }
  .q { font-weight: 600; margin: 1rem 0 .2rem; }
  .q:first-child { margin-top: 0; }
  footer { color: #9a9a9f; font-size: .85rem; margin-top: 2.5rem; }
  @media (prefers-color-scheme: dark) {
    body { color: #ececf0; background: #0f0f10; }
    .sub { color: #9a9a9f; }
    .card { background: #1b1b1d; border-color: #2c2c2e; }
    a { color: #57d9a3; }
  }
"""


def _html_page(title: str, body: str) -> str:
    return (
        '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{title}</title>\n<style>{_PAGE_CSS}</style>\n</head>\n"
        f'<body>\n  <div class="wrap">\n{body}\n  </div>\n</body>\n</html>'
    )


SUPPORT_BODY = f"""    <h1>SmartSalat Support</h1>
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

      <p class="q">How do I delete my account?</p>
      <p style="margin:0">Open Settings and tap "Delete Account". This permanently removes your account, prayer history, and friends.</p>

      <p class="q">Is my data private?</p>
      <p style="margin:0">Yes. We collect only what's needed to sync your account and connect you with friends you choose. See our <a href="/privacy">Privacy Policy</a>.</p>
    </div>

    <footer>SmartSalat &middot; Contact: {SUPPORT_EMAIL}</footer>"""


@app.get("/support", response_class=HTMLResponse)
def support():
    return _html_page("SmartSalat — Support", SUPPORT_BODY)


PRIVACY_EFFECTIVE = "July 11, 2026"

PRIVACY_SECTIONS = [
    ("Overview",
     'SmartSalat ("the App", "we", "us") helps you track your daily prayers, view '
     "prayer times, find the Qibla direction, and share prayer streaks with friends. "
     "This Privacy Policy explains what information the App collects, how it is used, "
     "and the choices you have. By creating an account or using the App, you agree to "
     f"this policy. The App is operated by {OPERATOR_NAME}."),
    ("Information You Provide",
     "<ul><li><strong>Account details:</strong> a username and password you choose. Your "
     "password is stored only as a secure cryptographic hash (bcrypt) — we never store or "
     "see your actual password.</li>"
     "<li><strong>Prayer activity:</strong> the prayers you mark as completed (Fard, Sunnah, "
     "and Witr) and the streaks calculated from them.</li>"
     "<li><strong>Friends:</strong> a friend code generated for your account, and the friend "
     "connections and friend requests you create.</li></ul>"),
    ("Information Collected Automatically",
     "<ul><li><strong>Location:</strong> with your permission, the App uses your device's "
     "location to calculate accurate prayer times and the Qibla direction. Your location is "
     "used and stored only on your device — it is NOT sent to or stored on our servers. You "
     "may instead choose a city manually, or decline location access.</li>"
     "<li><strong>Notifications:</strong> if you allow them, prayer-time reminders are "
     "scheduled locally on your device. No data is sent to us to deliver them.</li>"
     "<li><strong>Session token:</strong> when you sign in, a session token is stored on your "
     "device so you stay signed in.</li></ul>"),
    ("How We Use Your Information",
     "We use your information only to provide the App's features: to track your prayers and "
     "streaks, sync your data across your devices through your account, calculate prayer times "
     "and Qibla direction, send the prayer-time notifications you enable, and let your friends "
     "see your streak. We do not use your information for advertising."),
    ("How Your Information Is Shared",
     "<ul><li><strong>With friends:</strong> people you connect with can see your username, "
     "your current streak, and which prayers you have completed today.</li>"
     "<li><strong>Service providers:</strong> your account and prayer data are stored using "
     "MongoDB Atlas (database) and our server is hosted on Render. These providers process data "
     "solely on our behalf to operate the App.</li>"
     "<li>We do NOT sell your data, and the App contains no third-party advertising or analytics "
     "trackers.</li>"
     "<li>We may disclose information if required by law.</li></ul>"),
    ("Data Storage & Security",
     "Your account and prayer data are stored on our backend; other data (such as your saved "
     "location and session token) is stored locally on your device. Passwords are hashed with "
     "bcrypt, and data is transmitted over encrypted HTTPS connections. No method of storage or "
     "transmission is 100% secure, but we take reasonable measures to protect your information."),
    ("Your Choices & Data Deletion",
     "<ul><li>You can turn location and notification permissions on or off at any time in iOS "
     "Settings.</li>"
     "<li>You can permanently delete your account and all associated data at any time from within "
     'the App: open Settings and tap "Delete Account". This immediately removes your account, '
     "prayer records, friend connections, and session from our servers.</li>"
     f'<li>You may also request deletion by contacting us at <a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>.</li></ul>'),
    ("Children's Privacy",
     "The App is not directed to children under 13, and we do not knowingly collect personal "
     "information from children under 13. If you believe a child has provided us information, "
     "please contact us and we will delete it."),
    ("Changes to This Policy",
     "We may update this Privacy Policy from time to time. Changes take effect when posted, and "
     "material changes will require you to accept the updated policy before continuing to use the App."),
    ("Contact",
     "If you have any questions about this Privacy Policy or your data, contact us at "
     f'<a href="mailto:{SUPPORT_EMAIL}">{SUPPORT_EMAIL}</a>.'),
]


@app.get("/privacy", response_class=HTMLResponse)
def privacy():
    parts = [
        "    <h1>Privacy Policy</h1>",
        f'    <p class="sub">SmartSalat &middot; Effective {PRIVACY_EFFECTIVE}</p>',
    ]
    for title, html in PRIVACY_SECTIONS:
        parts.append(f'    <h2>{title}</h2>\n    <div class="card">{html}</div>')
    parts.append(f"    <footer>Operated by {OPERATOR_NAME} &middot; {SUPPORT_EMAIL}</footer>")
    return _html_page("SmartSalat — Privacy Policy", "\n".join(parts))


@app.post("/register", status_code=201)
def register(creds: Credentials, request: Request):
    rate_limit(request, "register", max_hits=5, window_secs=300)
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
def login(creds: Credentials, request: Request):
    rate_limit(request, "login", max_hits=10, window_secs=60)
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


@app.delete("/account", status_code=204)
def delete_account(username: str = Depends(current_user)):
    """Permanently delete the account and everything tied to it."""
    records_col.delete_many({"userId": username})
    sessions.delete_many({"username": username})
    # Remove this user from everyone else's friends lists and pending requests.
    users.update_many(
        {"$or": [{"friends": username}, {"incomingRequests": username}]},
        {"$pull": {"friends": username, "incomingRequests": username}},
    )
    users.delete_one({"_id": username})
    return None


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

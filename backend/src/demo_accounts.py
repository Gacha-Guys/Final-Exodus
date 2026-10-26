"""Users/Currency account access for the isolated demo."""
from datetime import date, datetime, timedelta, timezone
import hashlib
import secrets

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, field_validator
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from .demo_store import transaction

router = APIRouter()
password_hash = PasswordHash.recommended()
DUMMY_HASH = password_hash.hash(secrets.token_urlsafe(32))


class Body(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Name(Body):
    display_name: str = Field(min_length=1, max_length=64)

    @field_validator("display_name", mode="before")
    @classmethod
    def trim_name(cls, value):
        return value.strip() if isinstance(value, str) else value


class Registration(Name):
    email: EmailStr
    password: SecretStr = Field(min_length=12, max_length=128)
    dob: date

    @field_validator("dob")
    @classmethod
    def valid_birth_date(cls, value):
        if not date(1900, 1, 1) <= value <= date.today():
            raise ValueError("Enter a valid birth date from 1900 through today")
        return value


class Login(Body):
    email: EmailStr
    password: SecretStr = Field(min_length=1, max_length=128)


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


def authenticate(cursor, authorization):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Please log in again")
    token = authorization[7:]
    if not 20 <= len(token) <= 128:
        raise HTTPException(401, "Please log in again")
    cursor.execute("SELECT u_id FROM DemoSessions WHERE token_hash=%s AND expires_at>UTC_TIMESTAMP()",
                   (token_hash(token),))
    session = cursor.fetchone()
    if not session:
        raise HTTPException(401, "Session expired. Please log in again")
    return session["u_id"]


def profile(cursor, user_id):
    cursor.execute("SELECT id,email,name AS display_name,level,exp AS experience,gamepass FROM Users WHERE id=%s", (user_id,))
    account = cursor.fetchone()
    if not account:
        raise HTTPException(401, "Please log in again")
    cursor.execute("SELECT Type,count FROM Currency WHERE u_id=%s", (user_id,))
    balances = {row["Type"]: row["count"] for row in cursor.fetchall()}
    if any(kind not in balances or balances[kind] is None for kind in ("free", "paid")):
        raise HTTPException(503, "Account balances unavailable")
    account.update(free_currency=balances["free"], paid_currency=balances["paid"])
    account["gamepass"] = bool(account["gamepass"])
    cursor.execute("SELECT COUNT(*) AS total FROM DemoBattles WHERE u_id=%s AND JSON_UNQUOTE(JSON_EXTRACT(state,'$.status'))='won'", (user_id,))
    account["completed_battles"] = cursor.fetchone()["total"]
    return account


@router.post("/accounts", status_code=201)
def register(body: Registration):
    hashed = password_hash.hash(body.password.get_secret_value())
    with transaction() as cursor:
        cursor.execute("INSERT INTO Users(name,email,password,Dob) VALUES(%s,%s,%s,%s)",
                       (body.display_name, str(body.email).lower(), hashed, body.dob))
        return profile(cursor, cursor.lastrowid)


@router.post("/sessions")
def login(body: Login):
    with transaction() as cursor:
        cursor.execute("SELECT id,password FROM Users WHERE email=%s", (str(body.email).lower(),))
        account = cursor.fetchone()
        try:
            valid = password_hash.verify(body.password.get_secret_value(), account["password"] if account else DUMMY_HASH)
        except (UnknownHashError, ValueError):
            valid = False
        if not account or not valid:
            raise HTTPException(401, "Incorrect email or password")
        token = secrets.token_urlsafe(32)
        expiry = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(hours=8)
        cursor.execute("INSERT INTO DemoSessions(token_hash,u_id,expires_at) VALUES(%s,%s,%s)",
                       (token_hash(token), account["id"], expiry))
        return {"access_token": token, "token_type": "bearer", "expires_in": 28800}


@router.get("/me")
def me(authorization: str | None = Header(default=None)):
    with transaction() as cursor:
        return profile(cursor, authenticate(cursor, authorization))


@router.patch("/me")
def update_name(body: Name, authorization: str | None = Header(default=None)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        cursor.execute("UPDATE Users SET name=%s WHERE id=%s", (body.display_name, user_id))
        return profile(cursor, user_id)


@router.delete("/sessions/current", status_code=204)
def logout(authorization: str | None = Header(default=None)):
    with transaction() as cursor:
        authenticate(cursor, authorization)
        cursor.execute("DELETE FROM DemoSessions WHERE token_hash=%s", (token_hash(authorization[7:]),))

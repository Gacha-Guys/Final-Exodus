"""Secure aliases for earlier routes; identity always comes from a session."""
import os
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import Field
from .demo_accounts import Body, Login, Registration, register, verify_password
from .demo_store import transaction
from .demo_tokens import authenticate, authorization_header, issue_session

router = APIRouter(tags=["Compatibility"])


class LegacyLogin(Login):
    pass


class LegacySignup(Registration):
    display_name: str = Field(alias="name", min_length=1, max_length=255)


@router.post("/login")
def login(body: LegacyLogin):
    with transaction() as cursor:
        user_id = verify_password(cursor, body.name, body.password.get_secret_value())
        return {**issue_session(cursor, user_id), "id": user_id}


@router.post("/signup", status_code=201)
def signup(body: LegacySignup):
    return register(body)


@router.get("/currency")
def currency(u_id: int | None = None, authorization: str | None = Depends(authorization_header)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        if u_id is not None and u_id != user_id:
            raise HTTPException(403, "Account access denied")
        cursor.execute("SELECT Type,count FROM Currency WHERE u_id=%s", (user_id,))
        balances = {row["Type"]: row["count"] for row in cursor.fetchall()}
        if any(kind not in balances or balances[kind] is None for kind in ("free", "paid")):
            raise HTTPException(503, "Account balances unavailable")
        return balances


class CurrencyUpdate(Body):
    u_id: int | None = Field(default=None, ge=1, strict=True)
    amount: int = Field(strict=True, ge=-2147483648, le=2147483647)
    type: Literal["free", "paid"]


@router.post("/currency/update")
def update_currency(body: CurrencyUpdate, authorization: str | None = Depends(authorization_header)):
    with transaction() as cursor:
        user_id = authenticate(cursor, authorization)
        if body.u_id is not None and body.u_id != user_id:
            raise HTTPException(403, "Account access denied")
        # Preserve the teammate's prototype only in the guarded isolated fixture.
        # Neither a client body nor this flag can enable grants on shared storage.
        if (os.getenv("FINAL_EXODUS_STORAGE_PROFILE", "local-demo") != "local-demo"
                or os.getenv("FINAL_EXODUS_ENABLE_CURRENCY_PROTOTYPE") != "1"
                or os.getenv("FINAL_EXODUS_DB_HOST") not in ("127.0.0.1", "localhost")
                or os.getenv("FINAL_EXODUS_DB") != "final_exodus_tyler_demo"):
            raise HTTPException(410, "Currency prototype is available only in the opted-in isolated local demo")
        cursor.execute("SELECT count FROM Currency WHERE u_id=%s AND Type=%s FOR UPDATE", (user_id, body.type))
        row = cursor.fetchone()
        if not row or row["count"] is None:
            raise HTTPException(503, "Account balance unavailable")
        balance = row["count"] + body.amount
        if balance < 0:
            raise HTTPException(453, "Not enough currency")
        if balance > 2147483647:
            raise HTTPException(422, "Currency balance exceeds supported range")
        cursor.execute("UPDATE Currency SET count=%s WHERE u_id=%s AND Type=%s", (balance, user_id, body.type))
        return {"type": body.type, "count": balance}


@router.get("/account/inventory")
@router.get("/account/units")
@router.get("/unit")
def account_feature_placeholder(id: str = ""):
    raise HTTPException(501, "This feature is not implemented yet")

"""Secure aliases for earlier routes; identity always comes from a session."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import Field
from .account_routes import Login, Registration, register, verify_password
from .game_store import transaction
from .session_tokens import authenticate, authorization_header, issue_session

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


@router.get("/account/inventory")
@router.get("/account/units")
@router.get("/unit")
def account_feature_placeholder(id: str = ""):
    raise HTTPException(501, "This feature is not implemented yet")

"""Google OpenID Connect through the system browser; isolated local demo only."""
from dataclasses import dataclass
from datetime import date
import base64
import hashlib
import os
import secrets
import threading
import time
from urllib.parse import urlencode

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse
from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import id_token
import httpx
from pydantic import EmailStr, Field, SecretStr, TypeAdapter, field_validator

from .demo_accounts import Body, Name, Registration, require_available_name
from .demo_store import transaction
from .demo_tokens import issue_session

router = APIRouter(prefix="/auth/google", tags=["Google sign-in"])
REDIRECT = "http://127.0.0.1:8007/auth/google/callback"
AUTHORIZATION = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
FLOW_SECONDS = 300
lock = threading.Lock()
flows = {}


@dataclass
class Flow:
    poll_hash: str
    nonce: str
    verifier: str
    expires: float
    status: str = "pending"
    identity: dict | None = None
    error: str = ""


class FlowKey(Body):
    flow_id: str = Field(min_length=40, max_length=128)
    poll_secret: SecretStr = Field(min_length=40, max_length=128)


class GoogleRegistration(FlowKey, Name):
    dob: date | None = None

    # Reuse the same DOB rules as email registration.
    _valid_dob = field_validator("dob")(Registration.valid_birth_date.__func__)


def configuration():
    client_id = os.getenv("FINAL_EXODUS_GOOGLE_CLIENT_ID", "")
    client_secret = os.getenv("FINAL_EXODUS_GOOGLE_CLIENT_SECRET", "")
    if not client_id.endswith(".apps.googleusercontent.com") or not client_secret:
        raise HTTPException(503, "Google sign-in needs local OAuth setup. Use username/password for now.")
    return client_id, client_secret


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def prune():
    for key in list(flows):
        if flows[key].expires <= time.monotonic():
            del flows[key]


def get_flow(body):
    prune()
    flow = flows.get(body.flow_id)
    if not flow or not secrets.compare_digest(flow.poll_hash, digest(body.poll_secret.get_secret_value())):
        raise HTTPException(400, "Google sign-in expired or invalid. Start again.")
    return flow


@router.post("/start")
def start():
    client_id, _ = configuration()
    state, poll_secret, nonce, verifier = [secrets.token_urlsafe(32) for _ in range(4)]
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    with lock:
        prune()
        if len(flows) >= 100:
            raise HTTPException(429, "Too many sign-ins. Try again shortly.")
        flows[state] = Flow(digest(poll_secret), nonce, verifier, time.monotonic() + FLOW_SECONDS)
    query = dict(client_id=client_id, redirect_uri=REDIRECT, response_type="code", scope="openid email profile",
                 state=state, nonce=nonce, code_challenge=challenge, code_challenge_method="S256", prompt="select_account")
    return {"authorization_url": AUTHORIZATION + "?" + urlencode(query), "flow_id": state,
            "poll_secret": poll_secret, "expires_in": FLOW_SECONDS}


def verified_identity(code, flow):
    client_id, client_secret = configuration()
    # Both endpoints are fixed Google HTTPS addresses; never accept them from a client.
    with httpx.Client(timeout=5, follow_redirects=False) as client:
        response = client.post(TOKEN_ENDPOINT, data=dict(code=code, client_id=client_id, client_secret=client_secret,
                               redirect_uri=REDIRECT, grant_type="authorization_code", code_verifier=flow.verifier))
        response.raise_for_status()
        token = response.json()["id_token"]
    request = GoogleRequest()
    def bounded_request(url, **kwargs):
        return request(url=url, **(kwargs | {"timeout": 5}))
    claims = id_token.verify_oauth2_token(token, bounded_request, audience=client_id)
    if (claims.get("nonce") != flow.nonce or claims.get("email_verified") is not True
            or not isinstance(claims.get("sub"), str) or not 1 <= len(claims["sub"]) <= 255
            or claims.get("azp", client_id) != client_id):
        raise ValueError("Invalid Google identity")
    # Validate the address before storing it; identity is always Google's stable subject.
    email = str(TypeAdapter(EmailStr).validate_python(claims["email"])).lower()
    name = claims.get("name")
    return {"subject": claims["sub"], "email": email,
            "display_name": name.strip()[:64] if isinstance(name, str) and name.strip() else "Player"}


@router.get("/callback", response_class=HTMLResponse, include_in_schema=False)
def callback(state: str = Query(min_length=40, max_length=128),
             code: str | None = Query(default=None, max_length=4096),
             error: str | None = Query(default=None, max_length=256)):
    with lock:
        prune()
        flow = flows.get(state)
        if not flow or flow.status != "pending":
            raise HTTPException(400, "Google sign-in expired or already used. Start again.")
        flow.status = "exchanging"
    try:
        if error or not code:
            raise ValueError("Google sign-in cancelled")
        identity = verified_identity(code, flow)
        with lock:
            flow.identity, flow.status = identity, "verified"
    except (httpx.HTTPError, GoogleAuthError, ValueError, KeyError, TypeError):
        with lock:
            flow.status, flow.error = "failed", "Google sign-in failed or was cancelled. Please try again."
    # Do not echo callback parameters, provider errors, credentials or tokens into HTML.
    return HTMLResponse("<!doctype html><title>Final Exodus</title><h1>Return to Final Exodus</h1>"
                        "<p>You can close this tab and continue in the game.</p>",
                        headers={"Cache-Control": "no-store", "Referrer-Policy": "no-referrer",
                                 "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'"})


def existing_user(cursor, identity):
    cursor.execute("SELECT u_id FROM DemoGoogleIdentities WHERE subject=%s", (identity["subject"],))
    linked = cursor.fetchone()
    if linked:
        return linked["u_id"]
    cursor.execute("SELECT id FROM Users WHERE email=%s", (identity["email"],))
    if cursor.fetchone():
        raise HTTPException(409, "That email already has an account. Use its password; Google linking is not enabled.")
    return None


@router.post("/poll")
def poll(body: FlowKey):
    with lock:
        flow = get_flow(body)
        if flow.status == "failed":
            raise HTTPException(400, flow.error)
        if flow.status != "verified":
            return {"status": "pending"}
        with transaction() as cursor:
            user_id = existing_user(cursor, flow.identity)
            if user_id is None:
                return {"status": "registration_required", "display_name": flow.identity["display_name"]}
            result = issue_session(cursor, user_id)
        del flows[body.flow_id]
        return {"status": "authenticated", **result}


@router.post("/register")
def register(body: GoogleRegistration):
    with lock:
        flow = get_flow(body)
        if flow.status != "verified":
            raise HTTPException(400, "Finish Google sign-in in the browser first.")
        with transaction(identity_write=True) as cursor:
            require_available_name(cursor, body.display_name)
            if existing_user(cursor, flow.identity) is not None:
                raise HTTPException(409, "Account already exists. Start Google sign-in again.")
            cursor.execute("INSERT INTO Users(name,email,password,Dob) VALUES(%s,%s,%s,%s)",
                           (body.display_name, flow.identity["email"], "!google-only", body.dob))
            user_id = cursor.lastrowid
            cursor.execute("INSERT INTO DemoGoogleIdentities(subject,u_id) VALUES(%s,%s)",
                           (flow.identity["subject"], user_id))
            result = issue_session(cursor, user_id)
        del flows[body.flow_id]
        return {"status": "authenticated", **result}


@router.post("/cancel", status_code=204)
def cancel(body: FlowKey):
    with lock:
        get_flow(body)
        del flows[body.flow_id]

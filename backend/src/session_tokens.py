"""Signed API access tokens, with database revocation for immediate logout."""
from datetime import datetime, timedelta, timezone
import hashlib
import os
from uuid import uuid4

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import jwt

ISSUER = "final-exodus-local-api"
AUDIENCE = "final-exodus-game"
LIFETIME = 900
bearer = HTTPBearer(auto_error=False, bearerFormat="JWT")


def authorization_header(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
    return f"Bearer {credentials.credentials}" if credentials else None


def signing_key():
    key = os.getenv("FINAL_EXODUS_JWT_SECRET", "")
    if len(key) < 43:
        raise HTTPException(503, "Configure the private JWT signing key before starting the demo")
    return key


def token_hash(token):
    return hashlib.sha256(token.encode()).hexdigest()


def unauthorized():
    return HTTPException(401, "Session expired. Please log in again", headers={"WWW-Authenticate": "Bearer"})


def issue_session(cursor, user_id):
    now = datetime.now(timezone.utc)
    expires = now + timedelta(seconds=LIFETIME)
    token = jwt.encode(dict(sub=str(user_id), jti=str(uuid4()), iss=ISSUER, aud=AUDIENCE,
                            iat=now, nbf=now, exp=expires), signing_key(), algorithm="HS256")
    cursor.execute("INSERT INTO DemoSessions(token_hash,u_id,expires_at) VALUES(%s,%s,%s)",
                   (token_hash(token), user_id, expires.replace(tzinfo=None)))
    return {"access_token": token, "token_type": "bearer", "expires_in": LIFETIME}


def authenticate(cursor, authorization):
    if not authorization or not authorization.startswith("Bearer "):
        raise unauthorized()
    token = authorization[7:]
    if not 20 <= len(token) <= 4096:
        raise unauthorized()
    try:
        claims = jwt.decode(token, signing_key(), algorithms=["HS256"], issuer=ISSUER,
                            audience=AUDIENCE, options={"require": ["sub", "jti", "iss", "aud", "iat", "nbf", "exp"]})
        subject = claims["sub"]
        if not subject.isascii() or not subject.isdecimal() or not 0 < int(subject) <= 2147483647:
            raise unauthorized()
    except (jwt.InvalidTokenError, ValueError, AttributeError):
        raise unauthorized() from None
    cursor.execute("SELECT u_id FROM DemoSessions WHERE token_hash=%s AND expires_at>UTC_TIMESTAMP()",
                   (token_hash(token),))
    session = cursor.fetchone()
    if not session or str(session["u_id"]) != subject:
        raise unauthorized()
    return session["u_id"]

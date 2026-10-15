"""Account creation foundation; login and screens are separate changes."""
import os

import pymysql
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from .rate_limit import RegistrationLimiter
from pydantic import BaseModel, ConfigDict, EmailStr, Field, SecretStr, field_validator
from pwdlib import PasswordHash

app = FastAPI(title="Final Exodus accounts")
password_hash = PasswordHash.recommended()
registration_limiter = RegistrationLimiter(
    int(os.getenv("FINAL_EXODUS_REGISTRATION_LIMIT", "5")),
    int(os.getenv("FINAL_EXODUS_REGISTRATION_WINDOW", "60")),
)


@app.middleware("http")
async def throttle_registration(request: Request, call_next):
    if request.method == "POST" and request.url.path == "/accounts":
        client = request.client.host if request.client else "unknown"
        retry = registration_limiter.retry_after(client)
        if retry:
            return JSONResponse({"detail": "Too many registration attempts"}, 429,
                                headers={"Retry-After": str(retry)})
    return await call_next(request)


@app.exception_handler(RequestValidationError)
async def safe_field_errors(request, error):
    # Default Pydantic responses can echo secret input; return only field/message.
    return JSONResponse({"detail": [{"loc": list(item["loc"]),
                                    "msg": item["msg"], "type": item["type"]}
                                   for item in error.errors()]}, 422)


class Registration(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: EmailStr
    display_name: str = Field(min_length=1, max_length=64)
    password: SecretStr

    @field_validator("display_name", mode="before")
    @classmethod
    def trim_name(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("password")
    @classmethod
    def password_length(cls, value):
        # Provisional local policy. Do not trim or silently truncate passwords.
        if not 12 <= len(value.get_secret_value()) <= 128:
            raise ValueError("Password must contain 12 to 128 characters")
        return value


class Account(BaseModel):
    id: int
    email: str
    display_name: str


def connect():
    settings = dict(
        host=os.getenv("FINAL_EXODUS_DB_HOST", "127.0.0.1"),
        port=int(os.getenv("FINAL_EXODUS_DB_PORT", "3307")),
        user=os.environ["FINAL_EXODUS_DB_USER"],
        password=os.environ["FINAL_EXODUS_DB_PASSWORD"],
        database=os.getenv("FINAL_EXODUS_DB", "final_exodus_dev"),
        charset="utf8mb4", autocommit=False, connect_timeout=5,
    )
    if os.getenv("FINAL_EXODUS_DB_SOCKET"):
        settings["unix_socket"] = os.environ["FINAL_EXODUS_DB_SOCKET"]
    if os.getenv("FINAL_EXODUS_DB_SSL_CA"):
        settings.update(ssl_ca=os.environ["FINAL_EXODUS_DB_SSL_CA"],
                        ssl_verify_cert=True, ssl_verify_identity=True)
    if settings["host"] not in ("127.0.0.1", "localhost", "::1") and not settings.get("ssl_ca"):
        raise ValueError("Remote databases require a CA certificate")
    return pymysql.connect(**settings)


def create_account(request, connection_factory=connect):
    email = str(request.email).lower()
    hashed = password_hash.hash(request.password.get_secret_value())
    connection = connection_factory()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO accounts (email, display_name, password_hash) VALUES (%s,%s,%s)",
                (email, request.display_name, hashed),
            )
            account_id = cursor.lastrowid
            cursor.execute("INSERT INTO wallets (account_id, currency) VALUES (%s,0)", (account_id,))
        connection.commit()
        return Account(id=account_id, email=email, display_name=request.display_name)
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


@app.get("/health")
def health():
    # Process liveness only; this is not a database-readiness claim.
    return {"status": "running", "scope": "registration draft"}


@app.post("/accounts", response_model=Account, status_code=201)
def register(request: Registration):
    try:
        return create_account(request)
    except pymysql.err.IntegrityError as error:
        if error.args[0] == 1062:
            raise HTTPException(409, "Email already registered") from None
        raise HTTPException(503, "Account creation unavailable") from None
    except (pymysql.err.MySQLError, KeyError, ValueError, OSError):
        raise HTTPException(503, "Account creation unavailable") from None

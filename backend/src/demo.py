"""Explicit local-demo entrypoint; never migrates or writes the shared database."""
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from .accounts import safe_field_errors
from .demo_accounts import router as accounts
from .demo_combat import router as combat
from .demo_store import transaction
from .rate_limit import RegistrationLimiter

app = FastAPI(title="Final Exodus local demo")
app.add_exception_handler(RequestValidationError, safe_field_errors)
limiter = RegistrationLimiter(limit=20)


@app.middleware("http")
async def limit_auth(request: Request, call_next):
    if request.method == "POST" and request.url.path in ("/accounts", "/sessions"):
        retry = limiter.retry_after(request.client.host if request.client else "unknown")
        if retry:
            return JSONResponse({"detail": "Too many attempts. Wait a minute and retry"}, 429,
                                headers={"Retry-After": str(retry)})
    return await call_next(request)


@app.get("/health")
def health():
    with transaction() as cursor:
        cursor.execute("SELECT 1 FROM Users LIMIT 0")
    return {"status": "running", "database": "local demo"}


app.include_router(accounts)
app.include_router(combat)

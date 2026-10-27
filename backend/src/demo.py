"""Connected account/battle API with explicit local or migrated shared storage."""
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from .accounts import safe_field_errors
from .demo_accounts import router as accounts
from .demo_combat import router as combat
from .demo_google import router as google
from .demo_store import transaction
from .rate_limit import RegistrationLimiter

app = FastAPI(title="Final Exodus API")
app.add_exception_handler(RequestValidationError, safe_field_errors)
limiter = RegistrationLimiter(limit=20)


@app.middleware("http")
async def limit_auth(request: Request, call_next):
    if request.method == "POST" and request.url.path in ("/accounts", "/sessions", "/login", "/signup", "/auth/google/start", "/auth/google/register"):
        retry = limiter.retry_after(request.client.host if request.client else "unknown")
        if retry:
            return JSONResponse({"detail": "Too many attempts. Wait a minute and retry"}, 429,
                                headers={"Retry-After": str(retry)})
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    return response


@app.get("/health")
def health():
    with transaction() as cursor:
        cursor.execute("SELECT 1 FROM Users LIMIT 0")
    return {"status": "running", "scope": "accounts and saved battles"}


app.include_router(accounts)
app.include_router(combat)
app.include_router(google)

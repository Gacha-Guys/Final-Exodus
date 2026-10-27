"""Supported secure account/session/combat API with guarded storage."""
from fastapi import HTTPException
from .demo import app
from .compatibility import router

app.include_router(router)


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.post("/token", deprecated=True)
def retired_token():
    raise HTTPException(501, "Use /sessions for authentication")


@app.get("/auth-test", deprecated=True)
def retired_auth_test():
    raise HTTPException(501, "Login is not implemented yet")

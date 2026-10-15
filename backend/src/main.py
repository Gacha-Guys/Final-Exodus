"""Shared API entrypoint. Authentication is a future SCRUM-7 feature."""
from fastapi import HTTPException
from .accounts import app

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post("/token", deprecated=True)
def login_placeholder():
    # Never issue dummy credentials from the shared API.
    raise HTTPException(501, "Login is not implemented yet")

@app.get("/auth-test", deprecated=True)
def authentication_placeholder():
    raise HTTPException(501, "Login is not implemented yet")

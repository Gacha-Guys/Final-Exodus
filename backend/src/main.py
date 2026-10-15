"""
OAuth2 Authorization Setup for Final Exodus Backend:
1. OAuth2 Scheme: We initialized `OAuth2PasswordBearer(tokenUrl="token")`, which instructs FastAPI 
   to look for an `Authorization: Bearer <token>` header in incoming requests on protected routes.
2. Token Generation (`/token` POST endpoint): Accepts a username and password via form data 
   (`OAuth2PasswordRequestForm`). When a user logs in via the `/docs` UI or a client app, 
   this route validates their credentials and returns a JSON response containing an `access_token`.
3. Protected Endpoint (`/auth-test` GET endpoint): Uses `fapi.Depends(oauth2_scheme)` to require 
   a valid Bearer token before executing. If the token is missing or invalid, FastAPI automatically 
   responds with a `401 Unauthorized` error. If valid, it returns the {"Hello": "World"} message.

Note: Using `OAuth2PasswordRequestForm` requires the `python-multipart` package (`pip install python-multipart`).
"""

import fastapi as fapi
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
import uvicorn

# Note: FastAPI uses `title` rather than `name` for OpenAPI documentation metadata
app = fapi.FastAPI(
    title="final-exodus-backend", 
    version="0.1.0",
    description="Backend for Final Exodus"
)

# Points FastAPI to the "/token" endpoint for obtaining credentials
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post("/token")
def login_for_access_token(form_data: OAuth2PasswordRequestForm = fapi.Depends()):
    # Replace this dummy check with real database verification later
    if form_data.username != "admin" or form_data.password != "secret":
        raise fapi.HTTPException(
            status_code=fapi.status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Return the access token (in production, generate a signed JWT here)
    return {"access_token": form_data.username, "token_type": "bearer"}

@app.get("/auth-test")
def read_protected_root(token: str = fapi.Depends(oauth2_scheme)):
    # If the request reaches this line, a Bearer token was successfully provided
    return {"Hello": "World"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_read_root():
    """Test that the public root endpoint works without authentication."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"Hello": "World"}


def test_login_success():
    """Test logging in with valid credentials returns a Bearer token."""
    # OAuth2PasswordRequestForm expects form data (`data=`), not JSON (`json=`)
    response = client.post(
        "/token",
        data={"username": "admin", "password": "secret"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


def test_login_invalid_credentials():
    """Test logging in with a wrong password fails with 401."""
    response = client.post(
        "/token",
        data={"username": "admin", "password": "wrongpassword"}
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect username or password"


def test_unauthorized_request_no_token():
    """Test hitting the protected endpoint without a token header fails with 401."""
    response = client.get("/auth-test")
    assert response.status_code == 401
    assert response.json() == {"detail": "Not authenticated"}


def test_unauthorized_request_fake_token():
    """Test hitting the protected endpoint with a fake/invalid token fails with 401."""
    response = client.get(
        "/auth-test",
        headers={"Authorization": "Bearer fake-invalid-token"}
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid or expired authentication token"


def test_authorized_request_full_flow():
    """Test logging in, extracting the token, and making an authorized request."""
    # 1. Log in to get the token
    login_response = client.post(
        "/token",
        data={"username": "admin", "password": "secret"}
    )
    assert login_response.status_code == 200
    token = login_response.json()["access_token"]

    # 2. Use the token in the Authorization header
    auth_response = client.get(
        "/auth-test",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert auth_response.status_code == 200
    # Matches the response from the updated get_current_user version
    # (If using your first version without get_current_user, it returns {"Hello": "World"})
    assert auth_response.json()["Hello"] == "World"
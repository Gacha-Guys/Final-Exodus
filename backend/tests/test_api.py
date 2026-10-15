"""Jasoo's scaffold contract, with dummy authentication explicitly disabled."""
from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"Hello": "World"}

def test_placeholder_does_not_issue_tokens():
    response = client.post("/token", data={"username": "admin", "password": "secret"})
    assert response.status_code == 501
    assert "access_token" not in response.json()

def test_fake_token_does_not_grant_access():
    for headers in ({}, {"Authorization": "Bearer fake-invalid-token"}, {"Authorization": "Bearer admin"}):
        response = client.get("/auth-test", headers=headers)
        assert response.status_code == 501
        assert response.json() == {"detail": "Login is not implemented yet"}

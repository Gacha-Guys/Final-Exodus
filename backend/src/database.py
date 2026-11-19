"""Shared MySQL connection configuration for backend features.

Callers own commit/rollback and must close their connection.
"""
import os
from pathlib import Path

import pymysql

BACKEND_DIR = Path(__file__).resolve().parents[1]
DEFAULT_CA_PATH = Path("certs") / "ca.pem"


def verified_tls_settings(ca_override=None):
    """Resolve a CA file relative to the backend and require verified TLS."""
    ca_path = Path(ca_override).expanduser() if ca_override else DEFAULT_CA_PATH
    ca_path = BACKEND_DIR / ca_path
    if not ca_path.is_file():
        if ca_override:
            raise ValueError("FINAL_EXODUS_DB_SSL_CA does not point to a certificate file")
        raise ValueError("Save the Aiven CA certificate as backend/certs/ca.pem or set FINAL_EXODUS_DB_SSL_CA")
    return dict(ssl_ca=str(ca_path), ssl_verify_cert=True, ssl_verify_identity=True)


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
    ca_override = os.getenv("FINAL_EXODUS_DB_SSL_CA")
    if ca_override or settings["host"] not in ("127.0.0.1", "localhost", "::1"):
        settings.update(verified_tls_settings(ca_override))
    return pymysql.connect(**settings)

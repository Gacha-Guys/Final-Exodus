"""Shared MySQL connection configuration for backend features.

Callers own commit/rollback and must close their connection.
"""
import os
import pymysql


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

"""Refuse non-disposable storage before standalone test drivers start or clean up."""
import os


def require_local_test_database():
    if (os.getenv("FINAL_EXODUS_DB_HOST") not in ("127.0.0.1", "localhost")
            or os.getenv("FINAL_EXODUS_DB") != "final_exodus_tyler_demo"):
        raise ValueError("Test drivers require the isolated loopback demo database; never shared Aiven")

"""Guarded local/shared storage; this module never applies migrations."""
from contextlib import contextmanager
import os

from fastapi import HTTPException
import pymysql
from . import database
from .shared_schema import VERSION


@contextmanager
def transaction(*, identity_write=False):
    profile = os.getenv("FINAL_EXODUS_STORAGE_PROFILE", "local-demo")
    if profile not in ("local-demo", VERSION):
        raise HTTPException(503, "Select a supported storage profile")
    if profile == "local-demo" and (os.getenv("FINAL_EXODUS_DB_HOST") not in ("127.0.0.1", "localhost")
            or os.getenv("FINAL_EXODUS_DB") != "final_exodus_tyler_demo"):
        raise HTTPException(503, "Start the API with the isolated local demo configuration")
    connection = None
    identity_locked = False
    try:
        connection = database.connect()
        with connection.cursor(pymysql.cursors.DictCursor) as cursor:
            if identity_write:
                # Serialize API username writes before any table read establishes a
                # snapshot. The DB-wide lock also covers collation-equivalent names.
                cursor.execute("SELECT GET_LOCK(CONCAT('final-exodus-identity-',LEFT(SHA2(DATABASE(),256),32)),5) AS acquired")
                identity_locked = cursor.fetchone()["acquired"] == 1
                if not identity_locked:
                    raise HTTPException(503, "Account update busy. Retry shortly")
            if profile == VERSION:
                cursor.execute("SELECT version FROM FinalExodusSchemaMigrations WHERE version=%s", (VERSION,))
                if not cursor.fetchone():
                    raise HTTPException(503, "Shared storage migration has not been verified")
            yield cursor
        connection.commit()
    except pymysql.err.IntegrityError as error:
        if connection:
            connection.rollback()
        if error.args[0] == 1062:
            raise HTTPException(409, "That email or request already exists") from None
        raise HTTPException(503, "Database operation unavailable") from None
    except (pymysql.err.MySQLError, KeyError, OSError, ValueError):
        if connection:
            connection.rollback()
        raise HTTPException(503, "Database unavailable. Retry shortly") from None
    except Exception:
        if connection:
            connection.rollback()
        raise
    finally:
        if connection:
            try:
                if identity_locked:
                    with connection.cursor() as cursor:
                        cursor.execute("SELECT RELEASE_LOCK(CONCAT('final-exodus-identity-',LEFT(SHA2(DATABASE(),256),32)))")
            except pymysql.err.MySQLError:
                pass
            finally:
                # Closing the connection also releases the advisory lock if the
                # release query fails. Commit/rollback has already happened.
                connection.close()

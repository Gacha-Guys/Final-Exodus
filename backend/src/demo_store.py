"""Local demo storage. Production storage and Aiven migrations are separate work."""
from contextlib import contextmanager
import os

from fastapi import HTTPException
import pymysql
from . import database


@contextmanager
def transaction():
    if (os.getenv("FINAL_EXODUS_DB_HOST") not in ("127.0.0.1", "localhost")
            or os.getenv("FINAL_EXODUS_DB") != "final_exodus_tyler_demo"):
        raise HTTPException(503, "Start the API with the isolated local demo configuration")
    connection = None
    try:
        connection = database.connect()
        with connection.cursor(pymysql.cursors.DictCursor) as cursor:
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
            connection.close()

"""Shared API entrypoint. Authentication is a future SCRUM-7 feature."""
import pymysql
from fastapi import HTTPException
from pymysql.cursors import DictCursor

from .accounts import app
from dotenv import load_dotenv
from .database import connect
from pydantic import EmailStr, TypeAdapter, ValidationError
import os

env_path = os.path.join(os.path.dirname(__file__), "..", ".env")
load_dotenv(env_path, override=True)

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post("/login")
def login_placeholder(credentials: dict):
    name = str(credentials.get("name", ""))
    password = str(credentials.get("password", ""))

    connection = connect()
    cursor = connection.cursor(DictCursor)

    try:
        cursor.execute("SELECT id FROM Users WHERE name = %s AND password = %s", (name, password,))
        row = cursor.fetchone()
        if row is not None:
            return row
        else:
            raise HTTPException(401, "Incorrect credentials")

    finally:
        cursor.close()
        connection.close()

@app.post("/signup")
def signup(credentials: dict):
    name = str(credentials.get("name", ""))
    password = str(credentials.get("password", ""))
    email = str(credentials.get("email", ""))

    try:
        email = str(TypeAdapter(EmailStr).validate_python(email))
    except ValidationError:
        raise HTTPException(422, "Invalid email address")

    connection = connect()
    cursor = connection.cursor(DictCursor)

    try:
        cursor.execute("SELECT id FROM Users WHERE name = %s", (name,))
        row = cursor.fetchone()
        cursor.execute("SELECT id FROM Users WHERE email = %s", (email,))
        row2 = cursor.fetchone()

        if row is not None:
            raise HTTPException(409, "Account already exists")
        elif row2 is not None:
            raise HTTPException(409, "Account already exists")
        else:
            cursor.execute("INSERT INTO Users(name, password, email) VALUES(%s, %s, %s)", (name, password, email,))
            connection.commit()
            cursor.execute("SELECT id FROM users WHERE name = %s AND password = %s", (name, password,))
            return cursor.fetchone()

    finally:
        cursor.close()
        connection.close()

@app.get("/auth-test", deprecated=True)
def authentication_placeholder():
    raise HTTPException(501, "Login is not implemented yet")

"""
Database endpoint
CURRENTLY UNSAFE AND DOES NOT REQUIRE AUTHENTICATION
"""

@app.get("/currency")
def _get_currency_data(u_id: int):
    currency_dict = {}

    connection = connect()
    cursor = connection.cursor()

    try:
        cursor.execute("SELECT type, count FROM Currency WHERE u_id = %s", (u_id,))
        rows = cursor.fetchall()

        if not rows:
            raise HTTPException(401, "Incorrect ID")

        for row in rows:
            currency_dict[row[0]] = int(row[1])
        return currency_dict

    finally:
        cursor.close()
        connection.close()


@app.post("/currency/update")
def _update_currency(info: dict):
    u_id = int(info.get("u_id", ""))
    amt = int(info.get("amount", ""))
    type = str(info.get("type", ""))

    connection = connect()
    cursor = connection.cursor(DictCursor)

    try:
        cursor.execute("SELECT count FROM Currency WHERE u_id = %s AND type = %s", (u_id, type,))
        row = cursor.fetchone()
        owned = int(row["count"])

        if (owned + amt) < 0:
            raise HTTPException(453, "Not enough currency")

        cursor.execute("UPDATE Currency SET count = count + %s WHERE u_id = %s AND type = %s", (amt, u_id, type,))
        connection.commit()
        return {"type": type, "count": owned + amt}

    finally:
        cursor.close()
        connection.close()

# Get account inventory if needed?
@app.get("/account/inventory")
def _get_inventory_data(id: str = ""):
    # SQL query here
    return # Return SQL data here, using a dict, i.e "{'key': value}"

# Get account units if needed?
@app.get("/account/units")
def _get_units_data(id: str = ""):
    # SQL query here
    return # Return SQL data here, using a dict, i.e "{'key': value}"

# Get unit stats
@app.get("/unit")
def _get_unit_data(id: str = ""):
    # SQL query here
    return # Return SQL data here, using a dict, i.e "{'key': value}"
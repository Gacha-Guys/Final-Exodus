"""Create only the isolated loopback demo database; never run a shared migration."""
import argparse
import os
from pathlib import Path
import secrets

from dotenv import dotenv_values
import pymysql

DATABASE = "final_exodus_tyler_demo"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--admin-env", required=True, type=Path)
    args = parser.parse_args()
    target = Path(__file__).parent / ".env.demo"
    if target.exists():
        existing = dotenv_values(target)
        if existing.get("FINAL_EXODUS_DB_HOST") != "127.0.0.1" or existing.get("FINAL_EXODUS_DB") != DATABASE:
            raise SystemExit("Existing configuration is not the isolated local demo. No changes made.")
        private = dotenv_values(args.admin_env)
        with pymysql.connect(host="127.0.0.1", port=3307, user="root",
                             password=private["FINAL_EXODUS_ROOT_PASSWORD"], database=DATABASE) as connection:
            with connection.cursor() as cursor:
                cursor.execute((Path(__file__).parent / "demo/google_schema.sql").read_text())
        if not existing.get("FINAL_EXODUS_JWT_SECRET"):
            target.chmod(0o600)
            with target.open("a") as stream:
                stream.write("\nFINAL_EXODUS_JWT_SECRET=" + secrets.token_urlsafe(48) + "\n")
        target.chmod(0o600)
        print("Local auth setup ready. Existing accounts and battles preserved.")
        return
    private = dotenv_values(args.admin_env)
    password = secrets.token_urlsafe(32)
    connection = pymysql.connect(host="127.0.0.1", port=3307, user="root",
                                 password=private["FINAL_EXODUS_ROOT_PASSWORD"],
                                 charset="utf8mb4", autocommit=True)
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=%s", (DATABASE,))
            if cursor.fetchone():
                raise SystemExit("Demo database already exists without this configuration. Inspect it before proceeding.")
            cursor.execute(f"CREATE DATABASE `{DATABASE}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            cursor.execute(f"USE `{DATABASE}`")
            # The trigger body contains semicolons, so treat that block as one statement.
            schema = (Path(__file__).parent / "demo/schema.sql").read_text()
            before, rest = schema.split("CREATE TRIGGER", 1)
            trigger, after = rest.split("END;", 1)
            for statement in before.split(";"):
                if statement.strip():
                    cursor.execute(statement)
            cursor.execute("CREATE TRIGGER" + trigger + "END")
            for statement in after.split(";"):
                if statement.strip():
                    cursor.execute(statement)
            cursor.execute((Path(__file__).parent / "demo/google_schema.sql").read_text())
            cursor.execute("CREATE USER 'tyler_demo_api'@'%%' IDENTIFIED BY %s", (password,))
            cursor.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON `{DATABASE}`.* TO 'tyler_demo_api'@'%'")
        content = ("FINAL_EXODUS_DB_HOST=127.0.0.1\nFINAL_EXODUS_DB_PORT=3307\n"
                   "FINAL_EXODUS_DB_USER=tyler_demo_api\n"
                   f"FINAL_EXODUS_DB_PASSWORD={password}\nFINAL_EXODUS_DB={DATABASE}\n"
                   f"FINAL_EXODUS_JWT_SECRET={secrets.token_urlsafe(48)}\n")
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        print("Created isolated local demo database and private backend/.env.demo.")
    finally:
        connection.close()


if __name__ == "__main__":
    main()

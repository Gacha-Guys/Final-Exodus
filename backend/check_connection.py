"""Read-only connection check; reads configuration from an explicitly supplied env file."""
import argparse
from dotenv import load_dotenv
from src.database import connect

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", required=True)
    args = parser.parse_args()
    load_dotenv(args.env_file, override=True)
    try:
        connection = connect()
        try:
            cursor = connection.cursor()

            cursor.execute("SELECT DATABASE(), @@hostname, USER()")
            row = cursor.fetchone()
            print("Database:", row[0])
            print("Server host:", row[1])
            print("Connected as:", row[2])

            cursor.execute("SHOW TABLES")
            tables = cursor.fetchall()
            print("Tables found:")
            for table in tables:
                print("  -", table[0])

            cursor.close()
        finally:
            connection.close()
    except Exception:
        import traceback

        traceback.print_exc()
        raise SystemExit(1)

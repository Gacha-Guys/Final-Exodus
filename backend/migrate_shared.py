"""Review an additive migration; writes require --apply and exact database confirmation."""
import argparse
import os
from dotenv import load_dotenv
from src.database import connect
from src.shared_schema import apply_migration, migration_plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm-database")
    args = parser.parse_args()
    load_dotenv(args.env_file, override=True)
    if args.apply and args.confirm_database != os.environ.get("FINAL_EXODUS_DB"):
        raise SystemExit("--confirm-database must exactly match the configured database")
    connection = connect()
    try:
        with connection.cursor() as cursor:
            plan = migration_plan(cursor)
            print("Additive migration plan:")
            for statement in plan:
                print(statement)
            if args.apply:
                apply_migration(cursor)
                connection.commit()
                print("Migration complete; existing Users/Currency rows and trigger preserved.")
            else:
                print("Dry run only. No changes applied.")
    finally:
        connection.close()


if __name__ == "__main__":
    main()

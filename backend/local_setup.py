"""Start an isolated local MySQL and create private application configuration."""
import argparse
import os
from pathlib import Path
import secrets
import subprocess
import sys

BACKEND = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=3308)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535:
        parser.error("Choose an unprivileged local port from 1024 through 65535")
    if (BACKEND / ".env.demo").exists():
        from dotenv import dotenv_values
        existing = dotenv_values(BACKEND / ".env.demo")
        if existing.get("FINAL_EXODUS_DB_HOST") != "127.0.0.1" or existing.get("FINAL_EXODUS_DB_PORT") != str(args.port):
            raise SystemExit("Existing app configuration uses another instance. Preserve it and choose a separate checkout.")
    private = BACKEND / ".env.mysql-local"
    if not private.exists():
        fd = os.open(private, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as stream:
            stream.write("FINAL_EXODUS_ROOT_PASSWORD=" + secrets.token_urlsafe(32) + "\n")
    private.chmod(0o600)
    environment = os.environ | {"FINAL_EXODUS_LOCAL_DB_PORT": str(args.port)}
    subprocess.run(["docker", "compose", "--project-name", "final-exodus-local", "--env-file", str(private),
                    "-f", str(BACKEND / "compose.local.yaml"), "up", "-d", "--wait"],
                   env=environment, check=True)
    subprocess.run([sys.executable, str(BACKEND / "setup_demo.py"), "--admin-env", str(private),
                    "--port", str(args.port)], check=True)
    print("Local MySQL is ready. Use the ignored backend/.env.demo to start the API.")


if __name__ == "__main__":
    main()

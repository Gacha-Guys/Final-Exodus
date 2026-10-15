# Account creation backend

Small foundation for SCRUM-6. A basic GDScript registration test screen is included; login is separate. Riley can build on this boilerplate against [the account contract](../docs/ACCOUNTS.md).

Use Python 3.11+ and MySQL 8.4. From this folder, create a virtual environment, activate it, then run `python -m pip install -r requirements-lock.txt`. Copy `.env.example` to a private `.env` and fill it using the team's privately shared connection settings and Aiven CA certificate. Never commit credentials or certificates. The Aiven service must be powered on.

An administrator applies `001_accounts.sql` once to a new database. The API user needs SELECT/INSERT on accounts and wallets; it does not need administrator access. The existing shared Aiven database already has these tables.

Run `python check_connection.py --env-file .env` for a read-only check. Run `python -m uvicorn app:app --env-file .env --host 127.0.0.1 --port 8001 --no-proxy-headers` for local testing. API reference: http://127.0.0.1:8001/docs. Never send real passwords over non-local HTTP; shared testing needs an HTTPS API deployment. Godot connects to this API, never directly to MySQL.

Run tests from this folder: `python -m unittest discover -s tests -v`.

This is a single-process development foundation. The default registration throttle is 5 attempts per IP per 60 seconds, including invalid requests; deployment needs a shared throttle and reviewed proxy setup. Identifier normalization, password policy, verification and age-data collection remain team decisions. A team onboarding guide will be written with Tyler separately.

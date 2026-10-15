# Backend setup — Final Exodus

Godot → Python/FastAPI → Aiven MySQL. This PR builds on Jasoo's `src/` backend and pytest setup. **Run one API: `src.main:app`.** Registration works; login is not implemented. The old dummy `/token` and `/auth-test` routes now return 501 and issue no tokens.

## 1. Get access to the team's existing Aiven database

1. Accept the Aiven invitation sent to your teammate email and sign into [Aiven Console](https://console.aiven.io/). Use that same email. If no invitation arrived, ask Tyler to invite/resend it.
2. Select **My Organization → final-exodus → final-exodus-mysql**. Do not create another service or select a paid plan.
3. If you cannot see the project, ask Tyler to grant access under **final-exodus → Permissions → Grant permissions → Grant to users** after your organization invitation is accepted. GitHub access and Aiven access are separate.
4. The service must say **Running**. If it is powered off, ask the project owner to start it and wait for Running before testing.
5. Ask Tyler for the **API application's MySQL credentials**, shared privately. Your Aiven website login is not the database username/password. Do not use the database administrator account for the API.
6. Open the service's **Overview → Connection information** to confirm the hostname, port and database. Download the project's **CA certificate** and save it outside the repository, e.g. `C:/Users/YourName/.final-exodus/ca.pem` or `/Users/yourname/.final-exodus/ca.pem`. If you cannot view/download these, ask Tyler to provide the connection details and certificate privately.

The normal API database user needs SELECT/INSERT on `accounts` and `wallets`. An administrator sets up those grants and applies `001_accounts.sql` once; teammates do not need to rerun it on the existing shared database. Console project membership does not automatically configure database credentials on your laptop.

References: [Aiven project permissions](https://aiven.io/docs/platform/howto/manage-permissions), [MySQL connection information](https://aiven.io/docs/products/mysql/howto/connect-from-mysql-workbench), [CA certificates](https://aiven.io/docs/platform/concepts/tls-ssl-certificates).

## 2. Install the Python backend

Install Python 3.11 or newer. Open a terminal inside this repository's `backend` folder.

**Windows PowerShell:**

```powershell
py -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements-lock.txt
Copy-Item .env.example .env
```

**macOS/Linux:**

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
cp .env.example .env
```

No environment activation is necessary with these commands. If you prefer Jasoo's `uv` workflow, `uv venv` and `uv pip install -r requirements-lock.txt` are equivalent setup options. `requirements.txt` declares dependencies; `requirements-lock.txt` pins the tested versions. Update both intentionally when dependencies change, rather than replacing the declaration file with every package installed on your machine.

## 3. Configure your private settings

Edit `backend/.env` locally. Replace **every placeholder** with the supplied values:

```dotenv
FINAL_EXODUS_DB_HOST=your-service-hostname
FINAL_EXODUS_DB_PORT=your-service-port
FINAL_EXODUS_DB_USER=your-api-user
FINAL_EXODUS_DB_PASSWORD=your-private-password
FINAL_EXODUS_DB=defaultdb
FINAL_EXODUS_DB_SSL_CA="C:/Users/YourName/.final-exodus/ca.pem"
```

On Mac, change the CA path to your actual `/Users/.../ca.pem` path. Use the provided database name if it differs from `defaultdb`. Put values containing `#` or spaces in quotes. Never paste the password into Godot, GitHub, screenshots, PRs or test files. `.env` is ignored by Git; `.env.example` contains placeholders only. Do not disable certificate verification to fix connection errors.

## 4. Check the database and start the API

**Windows:**

```powershell
.venv\Scripts\python.exe check_connection.py --env-file .env
.venv\Scripts\python.exe -m uvicorn src.main:app --env-file .env --host 127.0.0.1 --port 8001 --no-proxy-headers
```

**macOS/Linux:**

```sh
.venv/bin/python check_connection.py --env-file .env
.venv/bin/python -m uvicorn src.main:app --env-file .env --host 127.0.0.1 --port 8001 --no-proxy-headers
```

The first command should say **Connected: accounts and wallets are readable.** It does not create records. Leave the second command running. Open http://127.0.0.1:8001/docs for the API reference.

## 5. Try registration through the API

With the API running, open http://127.0.0.1:8001/docs. Expand **POST /accounts**, choose **Try it out**, and supply a disposable test email, display name, and a 12–128 character password. Execute to create a real test account in the shared database. A repeated email should return409. No login or phone registration screen is included in this backend PR; the Godot screen follows separately.

## Troubleshooting

| Problem | Check |
|---|---|
| No Aiven project visible | Accept organization invitation, then have Tyler grant project access. |
| Hostname cannot resolve / cannot connect | Confirm the service is Running and copy the current hostname/port. |
| Access denied | Use the API database credentials, not your Aiven website password; ask Tyler to check grants. |
| Certificate error | Check the CA path and certificate match this project. Keep verification enabled. |
| Address already in use | Stop your older API, or choose another port and use that port in Godot too. |
| Health works but registration fails | Health checks only the API process; run the database checker and confirm tables/grants. |
| Too many attempts | Wait at least 60 seconds. The default limit is 5 registration attempts per IP/minute, including invalid requests. |

Run [the automated tests](../docs/TESTING.md) before requesting review. The limiter is for a single local worker; shared deployment requires a reviewed proxy/throttle setup. Account/password/age policies are still provisional. Registration does not implement login or purchase eligibility.

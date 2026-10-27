# Backend setup — Final Exodus

Godot → Python/FastAPI → Aiven MySQL. The API uses the shared `src/` backend and pytest setup. **Run one API: `src.main:app`.** Registration and username/password login use the team’s `Users`/`Currency` schema, Argon2 password hashes and revocable JWT sessions. The old dummy `/token` and `/auth-test` routes return 501 and issue no tokens. The historical `src.accounts` module and its tests remain available but are not mounted into the supported API.

## 1. Get access to the team's existing Aiven database

1. Accept the Aiven invitation sent to your teammate email and sign into [Aiven Console](https://console.aiven.io/). Use that same email. If no invitation arrived, ask Tyler to invite/resend it.
2. Select **My Organization → final-exodus → final-exodus-mysql**. Do not create another service or select a paid plan.
3. If you cannot see the project, ask Tyler to grant access under **final-exodus → Permissions → Grant permissions → Grant to users** after your organization invitation is accepted. GitHub access and Aiven access are separate.
4. The service must say **Running**. If it is powered off, ask the project owner to start it and wait for Running before testing.
5. Ask Tyler for the **API application's MySQL credentials**, shared privately. Your Aiven website login is not the database username/password. Do not use the database administrator account for the API.
6. Open the service's **Overview → Connection information** to confirm the hostname, port and database. Download the project's **CA certificate** and save it outside the repository, e.g. `C:/Users/YourName/.final-exodus/ca.pem` or `/Users/yourname/.final-exodus/ca.pem`. If you cannot view/download these, ask Tyler to provide the connection details and certificate privately.

The normal API uses the existing `Users`/`Currency` tables and the reviewed additive session/battle tables. An administrator applies the [shared migration and scoped grants](../docs/SHARED_STORAGE.md) once; teammates do not run the historical `001_accounts.sql` or local demo initializer against Aiven. Console project membership does not automatically configure database credentials on your laptop.

References: [Aiven project permissions](https://aiven.io/docs/platform/howto/manage-permissions), [MySQL connection information](https://aiven.io/docs/products/mysql/howto/connect-from-mysql-workbench), [CA certificates](https://aiven.io/docs/platform/concepts/tls-ssl-certificates).

## 2. Install the Python backend

Use Python 3.14 for the verified local environment; backend CI also checks Python 3.12. Open a terminal inside this repository's `backend` folder.

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
FINAL_EXODUS_DB=Final-Exodus-Database
FINAL_EXODUS_STORAGE_PROFILE=shared-users-v1
FINAL_EXODUS_JWT_SECRET=replace-with-your-private-random-signing-key
FINAL_EXODUS_DB_SSL_CA="C:/Users/YourName/.final-exodus/ca.pem"
```

On Mac, change the CA path to your actual `/Users/.../ca.pem` path. Use the provided database name if it differs from `Final-Exodus-Database`. Generate a private JWT signing key of at least 43 characters and preserve it across restarts. Put values containing `#` or spaces in quotes. Never paste the password into Godot, GitHub, screenshots, PRs or test files. `.env` is ignored by Git; `.env.example` contains placeholders only. Do not disable certificate verification to fix connection errors.

## 4. Check the database and start the API

**Windows:**

```powershell
.venv\Scripts\python.exe check_connection.py --env-file .env
.venv\Scripts\python.exe Server.py
```

**macOS/Linux:**

```sh
.venv/bin/python check_connection.py --env-file .env
.venv/bin/python Server.py
```

The first command prints the selected database/server and table names without creating records. Leave the second command running. `Server.py` defaults to `.env` and loopback port **8000**, matching the Godot client. Open http://127.0.0.1:8000/docs for the API reference. `GET /health` checks database readiness and the shared migration marker; session creation also needs the signing key.

## 5. Try registration through the API

With the API running, open http://127.0.0.1:8000/docs. Expand **POST /signup**, choose **Try it out**, and supply a disposable test `email`, `name` and `password`. The team form keeps these three fields; DOB is optional and hidden. Passwords must be nonempty and at most 128 characters; trimmed usernames are 1–255 characters. Repeated usernames or emails return 409. Log in through **POST /login** with `name` and `password`, or use Account in Godot. Successful login closes the popup; press **Start** to enter the team hub. Email is not a login alias. Guest Start still opens the hub preview without private account data.

## 6. View saved player accounts in MySQL Workbench

Aiven Console manages the database service. Its **Users** section lists database connection users, not players registered in our game. Use the separate **MySQL Workbench** desktop app to browse player records. Workbench is optional; you do not need to install a local MySQL server.

1. Install the build for your computer from [the official MySQL Workbench downloads](https://dev.mysql.com/downloads/workbench/). On Apple Silicon Mac, choose ARM64. On Windows, use the Windows installer.
2. Open Workbench. Next to **MySQL Connections**, click **+** and name the connection `Final Exodus - Aiven`.
3. Use **Standard (TCP/IP)**. Copy the hostname and port from your Aiven service and use the privately supplied API database username. Set **Default Schema** to the database name from your `.env` (use the exact privately supplied name).
4. In **SSL**, choose **Require and Verify Identity** and set **SSL CA File** to the downloaded project certificate. Leave client certificate/key empty unless the project owner explicitly provides them.
5. Select **Test Connection** and enter the API database password. Saving it to Keychain/Vault is optional. The app password is not your Aiven website password or game password.
6. Save and open the connection. If Workbench warns about MySQL 8.4 compatibility, basic SQL queries may still work; this is different from a failed TLS/certificate check. Do not bypass certificate failures.
7. Inside the SQL editor, choose the **Schemas** tab in the left sidebar. Expand **your configured schema → Tables → Users**. Right-click **Users → Select Rows** to browse records, or run the read-only query below to avoid displaying password hashes.

```sql
SELECT u.id, u.name, u.level, u.exp, c.Type, c.count
FROM `Final-Exodus-Database`.Users AS u
LEFT JOIN `Final-Exodus-Database`.Currency AS c ON c.u_id = u.id
WHERE u.email = 'your-test@example.com';
```

Replace `your-test@example.com` with the exact test email you registered. Email is unique; API signup, rename and Google registration reject duplicate usernames using the database’s collation and a shared advisory lock. Direct SQL writers must follow that identity policy too; no new unique-name database index is added. Replace `Final-Exodus-Database` with your configured database name if different. The existing trigger creates one free and one paid balance row, so two rows confirm a saved account and its balances. This is a read-only query. Do not edit other teammates' test accounts.

## Testing and checking the right server

From `backend/`, run `.venv\Scripts\python.exe -m pytest -q` on Windows or `.venv/bin/python -m pytest -q` on Mac/Linux. Ordinary tests need no Aiven account or credentials. [The testing guide](../docs/TESTING.md) explains the optional real-database test and its cleanup requirements.

The Godot API origin must match the port you started. The standard command above uses 8000. If another API already occupies it, use `Server.py --port 8004` and set `FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8004` for Godot too. A successful health check verifies that process’s configured storage readiness; it does not prove it is the intended Aiven database. Start it with the intended `.env`, run the read-only database checker, and verify the saved record through your Aiven Workbench connection. The MySQL port from Aiven and your local API port are different settings.

## Troubleshooting

| Problem | Check |
|---|---|
| No Aiven project visible | Accept organization invitation, then have Tyler grant project access. |
| Hostname cannot resolve / cannot connect | Confirm the service is Running and copy the current hostname/port. |
| Access denied | Use the API database credentials, not your Aiven website password; ask Tyler to check grants. |
| Certificate error | Check the CA path and certificate match this project. Keep verification enabled. |
| Address already in use | Stop your older API, or choose another port and use that port in Godot too. |
| Health works but registration fails | Run the database checker, confirm runtime grants and inspect the safe API error; health does not test every write or signing-key setting. |
| Too many attempts | Wait at least 60 seconds. The supported API allows 20 authentication/registration attempts per IP/minute, including invalid requests. |

Run [the automated tests](../docs/TESTING.md) before requesting review. The limiter is for a single local worker; shared deployment requires a reviewed proxy/throttle setup. Account/password/age policies are still provisional; DOB does not establish purchase eligibility. Existing unsupported shared password formats need owner-verified resets; no plaintext fallback is enabled.

## Isolated local prototype and optional demo

For Docker/local MySQL setup, see [LOCAL_DEMO.md](../docs/LOCAL_DEMO.md). Start that API with `Server.py --env-file .env.demo` on the same default port 8000. The first gem button retains Mihai’s +50 paid-currency prototype only when local setup enables it for loopback `final_exodus_tyler_demo`. Shared storage always refuses client-directed grants, even if that flag is set. Other offers and the gamepass retain their existing presentation.

The added fixture-combat/Google flow is separate: open `frontend/scenes/demo_title.tscn` and press F6. It does not replace the team’s F5 title/hub/navigation. See [authentication](../docs/AUTHENTICATION.md) for the explicit port 8007 Google callback setup and [API contracts](../docs/DEMO_API.md) for supported routes.

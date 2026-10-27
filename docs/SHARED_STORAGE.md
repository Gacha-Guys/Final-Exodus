# Shared Users/Currency integration

The supported API is `src.main:app` on port 8007. Its connected account and combat contract is in `DEMO_API.md`. The old `src.accounts` implementation remains testable but is not mounted into this API.

## Before applying the additive migration

1. Record the existing schema, trigger definition, row counts and a private backup. Verify the restore procedure on a disposable MySQL 8.4 instance.
2. Rehearse against that disposable clone, including existing rows and the actual Users/Currency trigger. Never run the local schema initializer against Aiven.
3. Run the migration preflight without `--apply`, using a private administrator environment:

```sh
python migrate_shared.py --env-file /private/path/migration.env
```

The preflight checks the required Users/Currency columns, missing/blank email values, normalized duplicate email groups, and the existing AFTER INSERT trigger. Resolve ambiguous existing identity data deliberately. The tool prints DDL, not player records or credentials.

4. After reviewing the dry run, apply to the explicitly confirmed database:

```sh
python migrate_shared.py --env-file /private/path/migration.env --apply --confirm-database EXACT_DATABASE_NAME
```

The tool adds nullable `Users.Dob` if absent, a unique normalized-email index, `DemoSessions`, `DemoBattles`, `DemoActions`, `DemoGoogleIdentities`, and `FinalExodusSchemaMigrations`. Existing IDs, balances, catalog, ownership rows, passwords and the Users/Currency trigger are preserved. Existing persistence tables must have compatible columns; a readiness check runs before recording `shared-users-v1`.

MySQL DDL auto-commits. A failed migration may leave already-created additive objects; inspect the failure and rerun after correction. The tool is idempotent for compatible schemas; it never drops/recreates Users, Currency, their trigger, or existing data. Do not treat transaction rollback as a complete DDL rollback.

## Existing accounts and authentication

New registration requires a real DOB and an Argon2 verifier. Existing DOB values may remain NULL; do not fill them with invented dates. Existing raw or unsupported password formats remain untouched by migration and are rejected by secure login. An account owner must complete a verified password reset before using such an account. This integration does not implement a public recovery feature or automatic account linking. Never log password values during compatibility checks.

Case-normalized duplicate emails must be resolved before applying the unique index. Legacy username login supports only an unambiguous matching account; email login is preferred. A matching Google email does not automatically link an existing password account.

## Application configuration and privileges

Use a separate private application environment with `FINAL_EXODUS_STORAGE_PROFILE=shared-users-v1`, the reviewed database name, a random JWT key of at least 43 characters, and verified TLS settings. `src.database.connect` rejects remote hosts without a CA and enables certificate/hostname verification. No application or Godot configuration should contain administrator credentials.

The application needs SELECT on its runtime tables, INSERT/UPDATE on Users, INSERT/DELETE on DemoSessions, INSERT/UPDATE on DemoBattles, INSERT/UPDATE on DemoActions, and INSERT on DemoGoogleIdentities. The replay journal's UPDATE privilege is required by MySQL's `SELECT ... FOR UPDATE` locking read; the API inserts immutable replay responses. Currency initialization runs through the preserved trigger rather than a second API write. Review actual grants narrowly; the API does not need CREATE, ALTER, DROP, GRANT or permission to modify catalog/ownership tables in the current account/battle slice. The migration administrator applies schema changes separately. The runtime requires SELECT on `FinalExodusSchemaMigrations` and refuses shared requests without its verified version marker.

The trigger initializes free/paid balances exactly once on registration. The API must not add a second balance initialization path. Battle victory state persists; XP/currency payouts, owned-roster combat and gacha remain separate features.

## Acceptance after migration

Verify existing row IDs/counts, balances, ownership and trigger remain unchanged; valid/duplicate registration; current and legacy login aliases; invalid/unsupported credentials; own-account-only currency/profile reads; logout revocation; saved battle resume; repeated/concurrent action handling; failed-transaction rollback; and two independently configured clients. Do not use the opt-in local demo test cleanup against Aiven. Record shared smoke checks separately using specifically authorized disposable identities and cleanup.

Aiven MySQL access and API hosting are separate. Each teammate may run the API locally against the shared database; a remotely hosted API instead requires HTTPS, callback configuration and reviewed worker/rate-limit behavior. The current Google callback remains loopback port 8007.

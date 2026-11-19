"""Additive Users/Currency migration. Importing this module never connects."""
VERSION = "shared-users-v1"


def preflight(cursor):
    cursor.execute("SELECT TABLE_NAME,COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('Users','Currency')")
    columns = {}
    for table, column in cursor.fetchall():
        columns.setdefault(table, set()).add(column.lower())
    required = {"Users": {"id", "name", "email", "password", "exp", "level", "gamepass"},
                "Currency": {"u_id", "type", "count"}}
    if any(not fields <= columns.get(table, set()) for table, fields in required.items()):
        raise ValueError("Expected the team's existing Users/Currency schema; no changes applied")
    cursor.execute("SELECT COUNT(*) FROM Users WHERE email IS NULL OR TRIM(email)=''")
    if cursor.fetchone()[0]:
        raise ValueError("Existing users need valid email addresses before migration")
    cursor.execute("SELECT COUNT(*) FROM (SELECT LOWER(TRIM(email)) FROM Users GROUP BY LOWER(TRIM(email)) HAVING COUNT(*)>1) AS duplicates")
    if cursor.fetchone()[0]:
        raise ValueError("Resolve duplicate normalized email addresses before migration")
    cursor.execute("SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE='Users' AND EVENT_MANIPULATION='INSERT' AND ACTION_TIMING='AFTER'")
    if not cursor.fetchone()[0]:
        raise ValueError("Expected the existing Users insert trigger; inspect the schema first")
    return columns


def migration_plan(cursor):
    columns = preflight(cursor)
    statements = []
    if "dob" not in columns["Users"]:
        statements.append("ALTER TABLE Users ADD COLUMN Dob DATE NULL")
    cursor.execute("SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='Users' AND INDEX_NAME='final_exodus_unique_email'")
    if not cursor.fetchone()[0]:
        statements.append("CREATE UNIQUE INDEX final_exodus_unique_email ON Users ((LOWER(TRIM(email))))")
    statements.extend([
        "CREATE TABLE IF NOT EXISTS DemoSessions (token_hash CHAR(64) PRIMARY KEY,u_id INT NOT NULL,expires_at DATETIME NOT NULL,FOREIGN KEY(u_id) REFERENCES Users(id) ON DELETE CASCADE)",
        "CREATE TABLE IF NOT EXISTS DemoBattles (id CHAR(36) PRIMARY KEY,u_id INT NOT NULL,request_id CHAR(36) NOT NULL,state JSON NOT NULL,created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6),UNIQUE KEY demo_start_request(u_id,request_id),FOREIGN KEY(u_id) REFERENCES Users(id) ON DELETE CASCADE)",
        "CREATE TABLE IF NOT EXISTS DemoActions (battle_id CHAR(36) NOT NULL,request_id CHAR(36) NOT NULL,actor INT NOT NULL,version INT NOT NULL,response JSON NOT NULL,PRIMARY KEY(battle_id,request_id),FOREIGN KEY(battle_id) REFERENCES DemoBattles(id) ON DELETE CASCADE)",
        "CREATE TABLE IF NOT EXISTS DemoGoogleIdentities (subject VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,u_id INT NOT NULL UNIQUE,FOREIGN KEY(u_id) REFERENCES Users(id) ON DELETE CASCADE)",
        "CREATE TABLE IF NOT EXISTS FinalExodusSchemaMigrations (version VARCHAR(64) PRIMARY KEY,applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)",
    ])
    return statements


def apply_migration(cursor):
    statements = migration_plan(cursor)
    for statement in statements:
        cursor.execute(statement)
    # Verify the adapter's actual columns before declaring readiness. DDL is additive
    # and MySQL auto-commits it; failed runs can be inspected and rerun safely.
    for query in (
        "SELECT Dob FROM Users LIMIT 0",
        "SELECT token_hash,u_id,expires_at FROM DemoSessions LIMIT 0",
        "SELECT id,u_id,request_id,state,created_at FROM DemoBattles LIMIT 0",
        "SELECT battle_id,request_id,actor,version,response FROM DemoActions LIMIT 0",
        "SELECT subject,u_id FROM DemoGoogleIdentities LIMIT 0",
    ):
        cursor.execute(query)
    cursor.execute("INSERT IGNORE INTO FinalExodusSchemaMigrations(version) VALUES(%s)", (VERSION,))
    return statements

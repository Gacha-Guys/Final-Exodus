-- Account creation foundation; login/session storage is a separate migration.
CREATE TABLE IF NOT EXISTS accounts (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(254) NOT NULL UNIQUE,
  display_name VARCHAR(64) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(16) NOT NULL DEFAULT 'player',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (role IN ('player', 'creator', 'admin'))
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS wallets (
  account_id BIGINT UNSIGNED PRIMARY KEY,
  currency BIGINT NOT NULL DEFAULT 0,
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
  CHECK (currency >= 0)
) ENGINE=InnoDB;

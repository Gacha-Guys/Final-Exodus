CREATE TABLE Users (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  exp INT DEFAULT 0,
  level INT DEFAULT 1,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  Dob DATE NULL,
  gamepass BOOLEAN DEFAULT FALSE,
  UNIQUE KEY demo_unique_email (email)
);
CREATE TABLE Currency (
  Type VARCHAR(255) NOT NULL,
  count INT DEFAULT 0,
  u_id INT NOT NULL,
  PRIMARY KEY (Type, u_id),
  FOREIGN KEY (u_id) REFERENCES Users(id) ON DELETE CASCADE
);
CREATE TRIGGER users_after_insert AFTER INSERT ON Users FOR EACH ROW
BEGIN
  INSERT INTO Currency (Type, count, u_id) VALUES ('free', 0, NEW.id);
  INSERT INTO Currency (Type, count, u_id) VALUES ('paid', 0, NEW.id);
END;
CREATE TABLE DemoSessions (
  token_hash CHAR(64) PRIMARY KEY,
  u_id INT NOT NULL,
  expires_at DATETIME NOT NULL,
  FOREIGN KEY (u_id) REFERENCES Users(id) ON DELETE CASCADE
);
CREATE TABLE DemoBattles (
  id CHAR(36) PRIMARY KEY,
  u_id INT NOT NULL,
  request_id CHAR(36) NOT NULL,
  state JSON NOT NULL,
  created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY demo_start_request (u_id, request_id),
  FOREIGN KEY (u_id) REFERENCES Users(id) ON DELETE CASCADE
);
CREATE TABLE DemoActions (
  battle_id CHAR(36) NOT NULL,
  request_id CHAR(36) NOT NULL,
  actor INT NOT NULL,
  version INT NOT NULL,
  response JSON NOT NULL,
  PRIMARY KEY (battle_id, request_id),
  FOREIGN KEY (battle_id) REFERENCES DemoBattles(id) ON DELETE CASCADE
);

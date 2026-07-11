-- Admin flag for catalog import and user management
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE users SET is_admin = TRUE WHERE id = (SELECT MIN(id) FROM users);

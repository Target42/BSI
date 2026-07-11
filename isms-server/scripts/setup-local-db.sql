-- Einmalig als PostgreSQL-Superuser ausführen (z. B. psql -U postgres -f scripts/setup-local-db.sql)
-- Passt User/Passwort an, falls du andere Credentials nutzt.

CREATE USER ismsserver WITH PASSWORD 'ismsserver';
CREATE DATABASE isms OWNER ismsserver;
GRANT ALL PRIVILEGES ON DATABASE isms TO ismsserver;

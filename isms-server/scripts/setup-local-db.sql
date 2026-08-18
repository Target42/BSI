-- Einmalig als PostgreSQL-Superuser ausführen.
-- Ubuntu:  sudo -u postgres psql -f scripts/setup-local-db.sql
-- Windows: psql -U postgres -f scripts/setup-local-db.sql
--
-- User/Passwort anpassen, falls du andere Credentials nutzt.
-- PostgreSQL 15+ (Ubuntu 24.04): ohne GRANT auf Schema public schlagen Migrationen fehl.

CREATE USER ismsserver WITH PASSWORD 'ismsserver';
CREATE DATABASE isms OWNER ismsserver;
GRANT ALL PRIVILEGES ON DATABASE isms TO ismsserver;

\connect isms
GRANT ALL ON SCHEMA public TO ismsserver;
ALTER SCHEMA public OWNER TO ismsserver;

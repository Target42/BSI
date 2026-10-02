DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM users GROUP BY lower(email) HAVING COUNT(*) > 1
    ) THEN
        CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_idx ON users (lower(email));
    END IF;
END $$;

CREATE TABLE project_invites (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('editor', 'reviewer', 'viewer')),
    created_by BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_project_invites_project
    ON project_invites (project_id)
    WHERE revoked_at IS NULL;

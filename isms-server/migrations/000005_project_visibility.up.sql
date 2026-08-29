ALTER TABLE projects
    ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'private';

ALTER TABLE projects
    DROP CONSTRAINT IF EXISTS projects_visibility_check;

ALTER TABLE projects
    ADD CONSTRAINT projects_visibility_check
    CHECK (visibility IN ('public', 'private'));

CREATE INDEX IF NOT EXISTS idx_projects_visibility ON projects (visibility);

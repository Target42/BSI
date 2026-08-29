DROP INDEX IF EXISTS idx_projects_visibility;

ALTER TABLE projects
    DROP CONSTRAINT IF EXISTS projects_visibility_check;

ALTER TABLE projects
    DROP COLUMN IF EXISTS visibility;

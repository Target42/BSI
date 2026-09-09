ALTER TABLE project_members DROP CONSTRAINT IF EXISTS project_members_role_check;
ALTER TABLE project_members
    ADD CONSTRAINT project_members_role_check
    CHECK (role IN ('owner', 'editor', 'viewer'));

DROP INDEX IF EXISTS idx_baustein_reviews_project_state;

ALTER TABLE baustein_reviews DROP COLUMN IF EXISTS returned_requirement_ids;

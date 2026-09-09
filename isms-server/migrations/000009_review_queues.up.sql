ALTER TABLE baustein_reviews
    ADD COLUMN IF NOT EXISTS returned_requirement_ids BIGINT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_baustein_reviews_project_state
    ON baustein_reviews (project_id, state);

ALTER TABLE project_members DROP CONSTRAINT IF EXISTS project_members_role_check;
ALTER TABLE project_members
    ADD CONSTRAINT project_members_role_check
    CHECK (role IN ('owner', 'editor', 'reviewer', 'viewer'));

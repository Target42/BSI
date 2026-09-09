ALTER TABLE projects
    ADD COLUMN IF NOT EXISTS workflow_enabled BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS baustein_reviews (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT NOT NULL REFERENCES target_objects (id) ON DELETE CASCADE,
    baustein_id BIGINT NOT NULL REFERENCES bausteine (id) ON DELETE CASCADE,
    state TEXT NOT NULL DEFAULT 'in_progress'
        CHECK (state IN ('in_progress', 'submitted', 'returned', 'accepted')),
    review_note TEXT NOT NULL DEFAULT '',
    submitted_by BIGINT REFERENCES users (id) ON DELETE SET NULL,
    submitted_at TIMESTAMPTZ,
    reviewed_by BIGINT REFERENCES users (id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, target_object_id, baustein_id)
);

CREATE INDEX IF NOT EXISTS idx_baustein_reviews_target
    ON baustein_reviews (project_id, target_object_id);

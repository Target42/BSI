CREATE TABLE IF NOT EXISTS baustein_review_events (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT NOT NULL REFERENCES target_objects (id) ON DELETE CASCADE,
    baustein_id BIGINT NOT NULL REFERENCES bausteine (id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('submit', 'return', 'accept')),
    from_state TEXT NOT NULL,
    to_state TEXT NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    returned_requirement_ids BIGINT[] NOT NULL DEFAULT '{}',
    actor_id BIGINT REFERENCES users (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_baustein_review_events_baustein
    ON baustein_review_events (project_id, target_object_id, baustein_id, created_at DESC, id DESC);

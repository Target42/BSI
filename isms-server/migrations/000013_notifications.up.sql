CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT REFERENCES target_objects (id) ON DELETE CASCADE,
    baustein_id BIGINT REFERENCES bausteine (id) ON DELETE SET NULL,
    kind TEXT NOT NULL CHECK (kind IN ('review_submitted', 'review_returned', 'review_accepted')),
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    link_path TEXT NOT NULL DEFAULT '',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user
    ON notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications (user_id, created_at DESC)
    WHERE read_at IS NULL;

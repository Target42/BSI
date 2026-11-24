ALTER TABLE target_objects
    ADD COLUMN IF NOT EXISTS editor_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_target_objects_editor
    ON target_objects (editor_user_id)
    WHERE editor_user_id IS NOT NULL;

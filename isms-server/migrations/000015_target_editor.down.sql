DROP INDEX IF EXISTS idx_target_objects_editor;

ALTER TABLE target_objects
    DROP COLUMN IF EXISTS editor_user_id;

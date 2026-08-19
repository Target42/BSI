CREATE TABLE baustein_deviations (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT NOT NULL REFERENCES target_objects (id) ON DELETE CASCADE,
    baustein_id BIGINT NOT NULL REFERENCES bausteine (id) ON DELETE CASCADE,
    note TEXT NOT NULL DEFAULT '',
    UNIQUE (project_id, target_object_id, baustein_id)
);

CREATE INDEX idx_baustein_deviations_target ON baustein_deviations (project_id, target_object_id);

ALTER TABLE requirement_assessments
    ADD COLUMN IF NOT EXISTS responsible_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE measures
    ADD COLUMN IF NOT EXISTS responsible_user_id BIGINT REFERENCES users (id) ON DELETE SET NULL;

UPDATE requirement_assessments a
SET responsible_user_id = m.user_id
FROM project_members m
JOIN users u ON u.id = m.user_id
WHERE a.project_id = m.project_id
  AND a.responsible_user_id IS NULL
  AND a.responsible IS NOT NULL
  AND btrim(a.responsible) <> ''
  AND lower(btrim(a.responsible)) IN (lower(u.email), lower(u.display_name));

UPDATE measures a
SET responsible_user_id = m.user_id
FROM project_members m
JOIN users u ON u.id = m.user_id
WHERE a.project_id = m.project_id
  AND a.responsible_user_id IS NULL
  AND a.responsible IS NOT NULL
  AND btrim(a.responsible) <> ''
  AND lower(btrim(a.responsible)) IN (lower(u.email), lower(u.display_name));

CREATE INDEX IF NOT EXISTS idx_assessments_responsible_user
    ON requirement_assessments (responsible_user_id)
    WHERE responsible_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_measures_responsible_user
    ON measures (responsible_user_id)
    WHERE responsible_user_id IS NOT NULL;

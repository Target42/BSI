DROP INDEX IF EXISTS idx_measures_responsible_user;
DROP INDEX IF EXISTS idx_assessments_responsible_user;

ALTER TABLE measures DROP COLUMN IF EXISTS responsible_user_id;
ALTER TABLE requirement_assessments DROP COLUMN IF EXISTS responsible_user_id;

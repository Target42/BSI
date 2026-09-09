DROP INDEX IF EXISTS idx_baustein_reviews_target;
DROP TABLE IF EXISTS baustein_reviews;

ALTER TABLE projects DROP COLUMN IF EXISTS workflow_enabled;

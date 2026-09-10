DROP INDEX IF EXISTS idx_baustein_reviews_assigned_reviewer;

ALTER TABLE baustein_reviews
    DROP COLUMN IF EXISTS assigned_reviewer_id;

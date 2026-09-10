ALTER TABLE baustein_reviews
    ADD COLUMN IF NOT EXISTS assigned_reviewer_id BIGINT REFERENCES users (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_baustein_reviews_assigned_reviewer
    ON baustein_reviews (assigned_reviewer_id)
    WHERE assigned_reviewer_id IS NOT NULL;

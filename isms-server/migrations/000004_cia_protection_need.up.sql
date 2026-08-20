ALTER TABLE target_objects
    ADD COLUMN IF NOT EXISTS confidentiality TEXT NOT NULL DEFAULT 'normal',
    ADD COLUMN IF NOT EXISTS integrity TEXT NOT NULL DEFAULT 'normal',
    ADD COLUMN IF NOT EXISTS availability TEXT NOT NULL DEFAULT 'normal',
    ADD COLUMN IF NOT EXISTS inherit_protection_need BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS protection_need_note TEXT NOT NULL DEFAULT '';

UPDATE target_objects
SET confidentiality = 'hoch',
    integrity = 'hoch',
    availability = 'hoch'
WHERE protection_need LIKE 'Erhöht%';

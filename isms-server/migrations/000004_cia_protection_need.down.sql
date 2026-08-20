ALTER TABLE target_objects
    DROP COLUMN IF EXISTS confidentiality,
    DROP COLUMN IF EXISTS integrity,
    DROP COLUMN IF EXISTS availability,
    DROP COLUMN IF EXISTS inherit_protection_need,
    DROP COLUMN IF EXISTS protection_need_note;

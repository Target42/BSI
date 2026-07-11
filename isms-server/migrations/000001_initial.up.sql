CREATE TABLE catalog_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE bausteine (
    id BIGSERIAL PRIMARY KEY,
    standard TEXT NOT NULL,
    external_id TEXT NOT NULL,
    title TEXT NOT NULL,
    group_name TEXT,
    catalog_version TEXT NOT NULL,
    UNIQUE (standard, external_id, catalog_version)
);

CREATE TABLE requirements (
    id BIGSERIAL PRIMARY KEY,
    baustein_id BIGINT NOT NULL REFERENCES bausteine (id) ON DELETE CASCADE,
    standard TEXT NOT NULL,
    external_id TEXT NOT NULL,
    baustein_external_id TEXT NOT NULL,
    title TEXT NOT NULL,
    text TEXT,
    level TEXT NOT NULL,
    responsible_role TEXT,
    withdrawn BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (standard, external_id, baustein_id)
);

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    catalog_version TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE project_members (
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),
    PRIMARY KEY (project_id, user_id)
);

CREATE TABLE target_objects (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    parent_id BIGINT NOT NULL DEFAULT 0,
    type TEXT NOT NULL,
    protection_need TEXT NOT NULL DEFAULT 'Normal (Basis + Standard)',
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE baustein_applicability (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT NOT NULL REFERENCES target_objects (id) ON DELETE CASCADE,
    baustein_id BIGINT NOT NULL REFERENCES bausteine (id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    UNIQUE (project_id, target_object_id, baustein_id)
);

CREATE TABLE requirement_assessments (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT NOT NULL DEFAULT 0,
    requirement_id BIGINT NOT NULL REFERENCES requirements (id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'Offen',
    note TEXT,
    responsible TEXT,
    due_date DATE,
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, target_object_id, requirement_id)
);

CREATE TABLE measures (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects (id) ON DELETE CASCADE,
    target_object_id BIGINT NOT NULL REFERENCES target_objects (id) ON DELETE CASCADE,
    requirement_id BIGINT NOT NULL REFERENCES requirements (id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    responsible TEXT,
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'Offen',
    version INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_requirements_baustein ON requirements (baustein_id);
CREATE INDEX idx_assessments_project ON requirement_assessments (project_id);
CREATE INDEX idx_assessments_target ON requirement_assessments (project_id, target_object_id);
CREATE INDEX idx_target_objects_project ON target_objects (project_id);
CREATE INDEX idx_applicability_target ON baustein_applicability (project_id, target_object_id);
CREATE INDEX idx_measures_requirement ON measures (project_id, target_object_id, requirement_id);

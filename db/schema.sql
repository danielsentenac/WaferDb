PRAGMA foreign_keys = ON;

BEGIN;

CREATE TABLE IF NOT EXISTS wafers (
    wafer_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    acquired_date TEXT NOT NULL CHECK (date(acquired_date) IS NOT NULL),
    reference_invoice TEXT,
    roughness_nm REAL CHECK (roughness_nm IS NULL OR roughness_nm >= 0),
    wafer_type TEXT NOT NULL,
    wafer_size_in REAL CHECK (wafer_size_in IS NULL OR wafer_size_in > 0),
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS wafer_metadata_history (
    wafer_metadata_history_id INTEGER PRIMARY KEY,
    wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE,
    changed_at TEXT NOT NULL CHECK (datetime(changed_at) IS NOT NULL),
    name TEXT NOT NULL,
    acquired_date TEXT NOT NULL CHECK (date(acquired_date) IS NOT NULL),
    reference_invoice TEXT,
    roughness_nm REAL CHECK (roughness_nm IS NULL OR roughness_nm >= 0),
    wafer_type TEXT NOT NULL,
    wafer_size_in REAL CHECK (wafer_size_in IS NULL OR wafer_size_in > 0),
    notes TEXT,
    change_summary TEXT,
    photo_content_type TEXT CHECK (photo_content_type IS NULL OR photo_content_type LIKE 'image/%'),
    photo_blob BLOB,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_wafer_metadata_history_wafer_changed_at
    ON wafer_metadata_history (
        wafer_id,
        changed_at DESC,
        wafer_metadata_history_id DESC
    );

CREATE TABLE IF NOT EXISTS usage_purposes (
    purpose_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL UNIQUE
);

INSERT OR IGNORE INTO usage_purposes (purpose_id, code, label) VALUES
    (1, 'operation', 'Operation'),
    (2, 'r_and_d', 'R&D');

CREATE TABLE IF NOT EXISTS wafer_statuses (
    status_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL UNIQUE,
    description TEXT
);

INSERT OR IGNORE INTO wafer_statuses (status_id, code, label, description) VALUES
    (1, 'new_out_of_box', 'New out-of-the-box', 'Fresh wafer with no recorded exposure history.'),
    (2, 'darkfield_background_todo', 'Darkfield background to be done', 'Baseline darkfield background has not been recorded yet.'),
    (3, 'darkfield_background_done', 'Darkfield background done', 'Baseline darkfield background is available.'),
    (4, 'darkfield_exposed_done', 'Darkfield inspection done', 'Darkfield inspection has been completed.'),
    (5, 'darkfield_inspection_todo', 'Darkfield inspection to be done', 'Darkfield inspection has not been recorded yet.');

CREATE TABLE IF NOT EXISTS location_types (
    location_type_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL UNIQUE
);

INSERT OR IGNORE INTO location_types (location_type_id, code, label) VALUES
    (1, 'tower', 'Tower'),
    (2, 'clean_room', 'Clean room'),
    (3, 'clean_room_subarea', 'Clean room sub-area'),
    (4, 'hall', 'Hall');

CREATE TABLE IF NOT EXISTS locations (
    location_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    location_type_id INTEGER NOT NULL REFERENCES location_types(location_type_id),
    parent_location_id INTEGER REFERENCES locations(location_id) ON DELETE RESTRICT,
    notes TEXT,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    UNIQUE (name, parent_location_id)
);

INSERT OR IGNORE INTO locations (code, name, location_type_id) VALUES
    ('NI', 'NI Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('WI', 'WI Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('NE', 'NE Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('WE', 'WE Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('PR', 'PR Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('BS', 'BS Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('SR', 'SR Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('INJ', 'INJ Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('DET', 'DET Tower', (SELECT location_type_id FROM location_types WHERE code = 'tower')),
    ('1500N', '1500N Clean Room', (SELECT location_type_id FROM location_types WHERE code = 'clean_room')),
    ('1500W', '1500W Clean Room', (SELECT location_type_id FROM location_types WHERE code = 'clean_room')),
    ('CB', 'CB Clean Room', (SELECT location_type_id FROM location_types WHERE code = 'clean_room')),
    ('NE_CR', 'NE Clean Room', (SELECT location_type_id FROM location_types WHERE code = 'clean_room')),
    ('WE_CR', 'WE Clean Room', (SELECT location_type_id FROM location_types WHERE code = 'clean_room')),
    ('NE_HALL', 'NE Hall', (SELECT location_type_id FROM location_types WHERE code = 'hall')),
    ('WE_HALL', 'WE Hall', (SELECT location_type_id FROM location_types WHERE code = 'hall'));

INSERT OR IGNORE INTO locations (code, name, location_type_id, parent_location_id) VALUES
    ('CB_SAS', 'CB SAS', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_INJ_LAB', 'CB INJ Lab', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_DET_LAB', 'CB Det Lab', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_MIRROR', 'CB Mirror', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_PAYLOAD', 'CB Payload', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_BASE_ROOM', 'CB Base Room', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_MAIN_HALL', 'CB Main Hall', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB')),
    ('CB_DET_SAS', 'CB Det SAS', (SELECT location_type_id FROM location_types WHERE code = 'clean_room_subarea'), (SELECT location_id FROM locations WHERE code = 'CB'));

CREATE TABLE IF NOT EXISTS wafer_status_history (
    wafer_status_history_id INTEGER PRIMARY KEY,
    wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE,
    status_id INTEGER NOT NULL REFERENCES wafer_statuses(status_id),
    effective_at TEXT NOT NULL CHECK (datetime(effective_at) IS NOT NULL),
    cleared_at TEXT CHECK (cleared_at IS NULL OR datetime(cleared_at) IS NOT NULL),
    notes TEXT,
    photo_content_type TEXT CHECK (photo_content_type IS NULL OR photo_content_type LIKE 'image/%'),
    photo_blob BLOB,
    CHECK (cleared_at IS NULL OR datetime(cleared_at) >= datetime(effective_at))
);

CREATE INDEX IF NOT EXISTS idx_wafer_status_history_wafer_effective_at
    ON wafer_status_history (wafer_id, effective_at DESC);

CREATE TABLE IF NOT EXISTS wafer_activities (
    activity_id INTEGER PRIMARY KEY,
    wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE,
    purpose_id INTEGER NOT NULL REFERENCES usage_purposes(purpose_id),
    observed_status_id INTEGER REFERENCES wafer_statuses(status_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    exposure_quantity REAL NOT NULL CHECK (exposure_quantity >= 0),
    exposure_unit TEXT NOT NULL CHECK (exposure_unit IN ('hours', 'days', 'months', 'years')),
    started_at TEXT CHECK (started_at IS NULL OR datetime(started_at) IS NOT NULL),
    ended_at TEXT CHECK (ended_at IS NULL OR datetime(ended_at) IS NOT NULL),
    observations TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (
        (started_at IS NULL AND ended_at IS NULL)
        OR (
            started_at IS NOT NULL
            AND ended_at IS NOT NULL
            AND datetime(ended_at) >= datetime(started_at)
        )
    )
);

CREATE INDEX IF NOT EXISTS idx_wafer_activities_wafer_id
    ON wafer_activities (wafer_id);

CREATE INDEX IF NOT EXISTS idx_wafer_activities_location_id
    ON wafer_activities (location_id);

CREATE TABLE IF NOT EXISTS darkfield_runs (
    darkfield_run_id INTEGER PRIMARY KEY,
    wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE,
    activity_id INTEGER REFERENCES wafer_activities(activity_id) ON DELETE SET NULL,
    run_type TEXT NOT NULL DEFAULT 'background' CHECK (run_type IN ('background', 'inspection')),
    measured_at TEXT NOT NULL CHECK (datetime(measured_at) IS NOT NULL),
    summary_notes TEXT,
    data_path TEXT NOT NULL CHECK (data_path LIKE '/data/prod/rd/vac/darkfield/%'),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_darkfield_runs_wafer_id
    ON darkfield_runs (wafer_id);

CREATE TABLE IF NOT EXISTS darkfield_bin_summaries (
    bin_summary_id INTEGER PRIMARY KEY,
    darkfield_run_id INTEGER NOT NULL REFERENCES darkfield_runs(darkfield_run_id) ON DELETE CASCADE,
    bin_order INTEGER NOT NULL CHECK (bin_order >= 1),
    bin_label TEXT,
    min_size_um REAL CHECK (min_size_um IS NULL OR min_size_um >= 0),
    max_size_um REAL CHECK (max_size_um IS NULL OR max_size_um >= 0),
    particle_count INTEGER NOT NULL DEFAULT 0 CHECK (particle_count >= 0),
    total_area_um2 REAL CHECK (total_area_um2 IS NULL OR total_area_um2 >= 0),
    particle_density_cm2 REAL CHECK (particle_density_cm2 IS NULL OR particle_density_cm2 >= 0),
    notes TEXT,
    CHECK (max_size_um IS NULL OR min_size_um IS NULL OR max_size_um >= min_size_um),
    UNIQUE (darkfield_run_id, bin_order)
);

CREATE VIEW IF NOT EXISTS wafer_current_status AS
SELECT
    w.wafer_id,
    w.name,
    s.code AS status_code,
    s.label AS status_label,
    h.effective_at,
    h.cleared_at,
    h.notes
FROM wafers w
LEFT JOIN wafer_status_history h
    ON h.wafer_status_history_id = (
        SELECT h2.wafer_status_history_id
        FROM wafer_status_history h2
        WHERE h2.wafer_id = w.wafer_id
        ORDER BY datetime(h2.effective_at) DESC, h2.wafer_status_history_id DESC
        LIMIT 1
    )
LEFT JOIN wafer_statuses s
    ON s.status_id = h.status_id;

CREATE VIEW IF NOT EXISTS wafer_activity_timeline AS
SELECT
    a.activity_id,
    w.name AS wafer_name,
    p.code AS purpose_code,
    p.label AS purpose_label,
    s.code AS status_code,
    s.label AS status_label,
    l.code AS location_code,
    l.name AS location_name,
    a.exposure_quantity,
    a.exposure_unit,
    a.started_at,
    a.ended_at,
    a.observations,
    a.created_at
FROM wafer_activities a
JOIN wafers w ON w.wafer_id = a.wafer_id
JOIN usage_purposes p ON p.purpose_id = a.purpose_id
LEFT JOIN wafer_statuses s ON s.status_id = a.observed_status_id
JOIN locations l ON l.location_id = a.location_id;

COMMIT;

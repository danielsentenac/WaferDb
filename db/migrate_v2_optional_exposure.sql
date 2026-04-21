-- Migration: make exposure_quantity/exposure_unit optional and allow open-ended activities
-- (started_at set without ended_at). SQLite requires table recreation to change constraints.

PRAGMA foreign_keys = OFF;

BEGIN;

CREATE TABLE wafer_activities_new (
    activity_id INTEGER PRIMARY KEY,
    wafer_id INTEGER NOT NULL REFERENCES wafers(wafer_id) ON DELETE CASCADE,
    purpose_id INTEGER NOT NULL REFERENCES usage_purposes(purpose_id),
    observed_status_id INTEGER REFERENCES wafer_statuses(status_id),
    location_id INTEGER NOT NULL REFERENCES locations(location_id),
    exposure_quantity REAL CHECK (exposure_quantity IS NULL OR exposure_quantity >= 0),
    exposure_unit TEXT CHECK (exposure_unit IS NULL OR exposure_unit IN ('hours', 'days', 'months', 'years')),
    started_at TEXT CHECK (started_at IS NULL OR datetime(started_at) IS NOT NULL),
    ended_at TEXT CHECK (ended_at IS NULL OR datetime(ended_at) IS NOT NULL),
    observations TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (exposure_quantity IS NULL OR exposure_unit IS NOT NULL),
    CHECK (exposure_unit IS NULL OR exposure_quantity IS NOT NULL),
    CHECK (
        ended_at IS NULL
        OR (
            started_at IS NOT NULL
            AND datetime(ended_at) >= datetime(started_at)
        )
    )
);

INSERT INTO wafer_activities_new SELECT * FROM wafer_activities;

DROP TABLE wafer_activities;
ALTER TABLE wafer_activities_new RENAME TO wafer_activities;

CREATE INDEX IF NOT EXISTS idx_wafer_activities_wafer_id
    ON wafer_activities (wafer_id);

CREATE INDEX IF NOT EXISTS idx_wafer_activities_location_id
    ON wafer_activities (location_id);

COMMIT;

PRAGMA foreign_keys = ON;

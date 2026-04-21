-- Migration: link auto-generated status history entries back to their source activity.
-- SQLite supports ADD COLUMN as long as it has no non-constant default and allows NULL.

PRAGMA foreign_keys = OFF;

BEGIN;

ALTER TABLE wafer_status_history
    ADD COLUMN source_activity_id INTEGER REFERENCES wafer_activities(activity_id) ON DELETE CASCADE;

COMMIT;

PRAGMA foreign_keys = ON;

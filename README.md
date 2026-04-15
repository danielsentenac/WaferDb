# WaferDb

SQLite schema and bootstrap tooling for tracking wafer inventory, usage history, and darkfield dust-monitoring results.

## Data model

The schema is normalized around a few core entities:

- `wafers`: master data for each wafer (`name`, acquisition date, invoice reference, roughness, type, size).
- `wafer_status_history`: status changes over time, using controlled values such as `new_out_of_box`, `darkfield_background_todo`, and `darkfield_background_done`.
- `wafer_activities`: exposure or usage events with purpose (`operation` or `r_and_d`), location, exposure duration, optional start/end timestamps, an optional observed status snapshot, and free-form observations.
- `locations`: controlled location catalog for towers and clean-room areas, with parent/child hierarchy for CB sub-areas.
- `darkfield_runs`: one row per microscopy run, including the run date and the expected storage path on `olserver135`.
- `darkfield_bin_summaries`: per-bin dust summary measurements attached to each darkfield run.

## Included locations

The initial seed data includes:

- Towers: `NI`, `WI`, `NE`, `WE`, `PR`, `BS`, `SR`, `INJ`, `DET`
- Clean rooms: `1500NW`, `CB`, `NE_CR`, `WE_CR`
- CB sub-areas: `CB_SAS`, `CB_INJ_LAB`, `CB_DET_LAB`, `CB_MIRROR`, `CB_PAYLOAD`, `CB_BASE_ROOM`, `CB_MAIN_HALL`, `CB_DET_SAS`

## Quick start

Create the SQLite database:

```bash
python3 scripts/init_db.py
```

By default this creates [data/waferdb.sqlite](/home/sentenac/WAFERDB/data/waferdb.sqlite).

To recreate the database from scratch:

```bash
python3 scripts/init_db.py --replace
```

## Example workflow

Insert a wafer:

```sql
INSERT INTO wafers (
    name,
    acquired_date,
    reference_invoice,
    roughness_nm,
    wafer_type,
    wafer_size_mm
) VALUES (
    'WAFER-001',
    '2026-04-15',
    'INV-12345',
    0.35,
    'silicon',
    100.0
);
```

Record its initial status:

```sql
INSERT INTO wafer_status_history (wafer_id, status_id, effective_at, notes)
SELECT
    w.wafer_id,
    s.status_id,
    '2026-04-15 09:00:00',
    'Received and registered.'
FROM wafers w
JOIN wafer_statuses s ON s.code = 'new_out_of_box'
WHERE w.name = 'WAFER-001';
```

Add an exposure activity:

```sql
INSERT INTO wafer_activities (
    wafer_id,
    purpose_id,
    observed_status_id,
    location_id,
    exposure_quantity,
    exposure_unit,
    started_at,
    ended_at,
    observations
)
SELECT
    w.wafer_id,
    p.purpose_id,
    s.status_id,
    l.location_id,
    72,
    'hours',
    '2026-04-18 08:00:00',
    '2026-04-21 08:00:00',
    'Installed for tower exposure campaign.'
FROM wafers w
JOIN usage_purposes p ON p.code = 'operation'
JOIN wafer_statuses s ON s.code = 'darkfield_background_done'
JOIN locations l ON l.code = 'NI'
WHERE w.name = 'WAFER-001';
```

When the baseline darkfield background is completed, record that as an official status change:

```sql
INSERT INTO wafer_status_history (wafer_id, status_id, effective_at, notes)
SELECT
    w.wafer_id,
    s.status_id,
    '2026-04-21 11:15:00',
    'Baseline darkfield background completed.'
FROM wafers w
JOIN wafer_statuses s ON s.code = 'darkfield_background_done'
WHERE w.name = 'WAFER-001';
```

Register a darkfield run and its dust bins:

```sql
INSERT INTO darkfield_runs (
    wafer_id,
    activity_id,
    run_type,
    measured_at,
    summary_notes,
    data_path
)
SELECT
    w.wafer_id,
    a.activity_id,
    'inspection',
    '2026-04-21 11:15:00',
    'Visible contamination increase after NI exposure.',
    '/data/prod/rd/vac/darkfield/WAFER-001/2026-04-21'
FROM wafers w
JOIN wafer_activities a ON a.wafer_id = w.wafer_id
WHERE w.name = 'WAFER-001'
ORDER BY a.activity_id DESC
LIMIT 1;

INSERT INTO darkfield_bin_summaries (
    darkfield_run_id,
    bin_order,
    bin_label,
    min_size_um,
    max_size_um,
    particle_count,
    total_area_um2
)
SELECT
    r.darkfield_run_id,
    1,
    '0-5 um',
    0.0,
    5.0,
    18,
    120.5
FROM darkfield_runs r
JOIN wafers w ON w.wafer_id = r.wafer_id
WHERE w.name = 'WAFER-001'
ORDER BY r.darkfield_run_id DESC
LIMIT 1;
```

## Useful queries

Current status per wafer:

```sql
SELECT * FROM wafer_current_status;
```

Full activity timeline with decoded lookups:

```sql
SELECT * FROM wafer_activity_timeline ORDER BY started_at, activity_id;
```

## Files

- [db/schema.sql](/home/sentenac/WAFERDB/db/schema.sql): schema and seed data
- [scripts/init_db.py](/home/sentenac/WAFERDB/scripts/init_db.py): creates the SQLite database from the schema

-- FUTURE EXTENSION
-- Multiple monthly customer snapshots for temporal modelling.
-- Resume after completing the single-snapshot pipeline.

-- ============================================================
-- Define monthly prediction snapshot dates
-- ============================================================

WITH snapshot_dates AS (
    SELECT
        snapshot_date::date
    FROM generate_series(
        DATE '2011-06-01',
        DATE '2011-11-01',
        INTERVAL '1 month'
    ) AS snapshot_date
)

SELECT
    snapshot_date,
    snapshot_date - INTERVAL '180 days' AS observation_start,
    snapshot_date AS observation_end,
    snapshot_date AS target_start,
    snapshot_date + INTERVAL '30 days' AS target_end
FROM snapshot_dates
ORDER BY snapshot_date;
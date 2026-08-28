{{ config(severity='error', group='analytics_engineering') }}

WITH duplicate_datetimes AS (
    SELECT
        TRY_TO_TIMESTAMP_NTZ(datetime) AS observation_datetime,
        COUNT(*) AS row_count
    FROM {{ source('ztc', 'weather_data') }}
    GROUP BY observation_datetime
    HAVING COUNT(*) > 1
),

classified AS (
    SELECT
        observation_datetime,
        row_count,
        observation_datetime IS NOT NULL
        AND row_count = 2
        AND MONTH(observation_datetime) = 10
        AND DAYOFWEEKISO(observation_datetime) = 7
        AND DAY(observation_datetime) BETWEEN 25 AND 31
        AND HOUR(observation_datetime) = 2 AS is_expected_dst_fallback
    FROM duplicate_datetimes
),

unexpected_duplicate_groups AS (
    SELECT
        observation_datetime,
        row_count,
        'unexpected duplicate timestamp shape' AS issue_type
    FROM classified
    WHERE NOT is_expected_dst_fallback
),

multiple_fallbacks_per_year AS (
    SELECT
        MIN(observation_datetime) AS observation_datetime,
        SUM(row_count) AS row_count,
        'multiple DST fallback duplicate groups in one year' AS issue_type
    FROM classified
    WHERE is_expected_dst_fallback
    GROUP BY YEAR(observation_datetime)
    HAVING COUNT(*) > 1
)

SELECT * FROM unexpected_duplicate_groups
UNION ALL
SELECT * FROM multiple_fallbacks_per_year

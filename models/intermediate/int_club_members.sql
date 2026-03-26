WITH source AS (
    SELECT * FROM {{ ref('stg_club_members') }}
)

-- Deduplicate on member_id, keeping the most recently joined record.
-- Duplicate clublidnummer values can appear in the source system (e.g. re-registrations).
SELECT * FROM source
QUALIFY ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY member_since DESC) = 1

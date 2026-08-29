-- Materialized as a table: eight downstream models join to this member grain,
-- so as a view the dedup window function and the CURRENT_DATE() enrichment
-- would be recomputed eight times per run.
{{
  config(
    materialized='table'
  )
}}

-- Member roster plus the attributes derived at query time from CURRENT_DATE().
-- This enrichment used to live in dim_members, which forced intermediate models
-- that needed age_group to depend on the core layer. Keeping it here means core
-- stays a thin publication layer and the intermediate layer is self-contained.
WITH club_members AS (
    SELECT * FROM {{ ref('int_club_members') }}
),

final AS (
    SELECT
        *,
        CAST(DATEDIFF('year', birth_date, CURRENT_DATE()) AS NUMBER(3, 0)) AS age,
        CAST({{ age_group("age") }} AS NUMBER(3, 0)) AS age_group,
        CAST(
            DATEDIFF('month', member_since, CURRENT_DATE()) AS NUMBER(6, 0)
        ) AS membership_length_in_months
    FROM club_members
)

SELECT * FROM final

-- Tier 1 — the cross-project contract.
--
-- ztc_analytics consumes this project via cross-project ref('ztc_core', ...).
-- A core model that is private breaks that ref; a core model without an
-- enforced contract lets a column rename ship silently and break it at run
-- time instead of at parse time. dbt_project.yml sets both defaults, so this
-- check exists to catch a per-model override that quietly opts out.
SELECT
    unique_id,
    access,
    contract_enforced
FROM {{ info_schema('models') }}
WHERE original_file_path LIKE 'models/core/%'
  AND (access != 'public' OR NOT contract_enforced)

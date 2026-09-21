-- Tier 1 — the other half of the boundary.
--
-- Staging and intermediate are implementation details. Marking one public
-- invites a downstream project to ref() it directly, which turns an internal
-- refactor into a breaking change for someone else.
SELECT
    unique_id,
    access
FROM {{ info_schema('models') }}
WHERE (original_file_path LIKE 'models/staging/%'
       OR original_file_path LIKE 'models/intermediate/%')
  AND access != 'private'

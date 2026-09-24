-- Tier 1 — a group is only useful if it routes to a human.
--
-- Every model in this project is assigned to a group, and access: private is
-- enforced against group boundaries. That machinery is pointless if the group
-- itself has no contactable owner, so require an email rather than just a name.
SELECT
    unique_id,
    name,
    owner_email
FROM {{ info_schema('groups') }}
WHERE COALESCE(TRIM(owner_email), '') = ''

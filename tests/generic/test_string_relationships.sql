{#-
  Like dbt's built-in `relationships` test, but casts both sides to VARCHAR before
  comparing. Use it for foreign keys whose child column and parent key have different
  types — e.g. the new demo facts carry member_id as VARCHAR (with 'GHOST-' orphans)
  while dim_members.member_id is NUMBER, so the standard test would fail on the cast.
  Returns child rows whose FK is non-null but has no match in the parent.
-#}
{% test string_relationships(model, column_name, to, field) %}

WITH child AS (
    SELECT {{ column_name }} AS from_field
    FROM {{ model }}
    WHERE {{ column_name }} IS NOT NULL
),

parent AS (
    SELECT {{ field }} AS to_field
    FROM {{ to }}
)

SELECT child.from_field
FROM child
LEFT JOIN parent
    ON CAST(child.from_field AS VARCHAR) = CAST(parent.to_field AS VARCHAR)
WHERE parent.to_field IS NULL

{% endtest %}

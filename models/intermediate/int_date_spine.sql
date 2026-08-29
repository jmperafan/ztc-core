-- Date spine covering every calendar day from start_date to the current date.
-- Lives in the intermediate layer so that other intermediate models can build
-- on it without reaching back into the published core layer; dim_calendar is a
-- passthrough of this model.
WITH RECURSIVE date_spine AS (
    SELECT DATE '{{ var('start_date') }}' AS date_key
    UNION ALL
    SELECT dateadd('day', 1, date_key)
    FROM date_spine
    WHERE date_key < current_date()
),

final AS (
    SELECT date_key
    FROM date_spine
    ORDER BY date_key DESC
)

SELECT date_key FROM final

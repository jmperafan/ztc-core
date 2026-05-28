{#-
    dutch_bool
    ----------
    Parses Dutch boolean text into a real SQL BOOLEAN. The ZTC reservation
    system stores yes/no flags as the literal Dutch words `ja` and `nee`,
    so columns like `clublid` and `bondslid` arrive as VARCHAR instead of
    BOOLEAN. This macro is the canonical conversion at the staging layer.

    Returns:
      - TRUE  when the trimmed, lowercased value is `ja`
      - FALSE when the trimmed, lowercased value is `nee`
      - NULL  for NULL, empty/whitespace-only strings, or anything else

    The macro is deliberately strict — unrecognised values become NULL
    rather than coercing to FALSE, so source drift surfaces in downstream
    not_null / accepted_values tests instead of silently changing semantics.
-#}
{% macro dutch_bool(column) %}
    CASE TRIM(LOWER({{ column }}))
        WHEN 'ja'  THEN TRUE
        WHEN 'nee' THEN FALSE
        ELSE NULL
    END
{% endmacro %}

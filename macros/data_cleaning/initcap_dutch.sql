{#-
    initcap_dutch
    -------------
    Title-cases a Dutch place name without the damage plain INITCAP does.

    Snowflake's INITCAP uppercases the first letter of every word and
    lowercases the rest. On this dataset that breaks two things:

      - The IJ digraph. 'IJsselstein' becomes 'Ijsselstein'. In Dutch both
        letters of the digraph carry the capital, so INITCAP is simply
        wrong -- and it is wrong on a value that arrived correct.
      - Two-letter province suffixes that disambiguate same-named towns.
        'BREUKELEN UT' becomes 'Breukelen Ut', where UT abbreviates the
        province of Utrecht.

    So the macro only rewrites values that arrive fully uppercased, which
    are the ones actually broken, and leaves correctly mixed-cased values
    alone. That guard is what keeps 'IJsselstein' intact.

    Measured on RAW.ZTC.CLUB_MEMBERS 2026-09-20: 78 of 430 `woonplaats`
    values arrive fully uppercased ('UTRECHT'); the rest already read
    'Utrecht'. Two carry a province suffix.
-#}
{% macro initcap_dutch(column) %}
    CASE
        -- Already mixed case, so already correct: IJsselstein, Utrecht.
        WHEN {{ column }} <> UPPER({{ column }})
            THEN {{ column }}
        -- Fully uppercase and ending in a two-letter province code. The
        -- code is sliced off the original (still uppercase) value and
        -- re-appended, which is cheaper than trying to uppercase a
        -- regex backreference.
        WHEN REGEXP_LIKE({{ column }}, '^.+ [A-Z]{2}$')
            THEN REGEXP_REPLACE(
                     INITCAP(LEFT({{ column }}, LENGTH({{ column }}) - 3)),
                     '^Ij',
                     'IJ'
                 ) || ' ' || RIGHT({{ column }}, 2)
        -- Plain fully-uppercase value: UTRECHT, DE MEERN, IJSSELSTEIN.
        ELSE REGEXP_REPLACE(INITCAP({{ column }}), '^Ij', 'IJ')
    END
{% endmacro %}

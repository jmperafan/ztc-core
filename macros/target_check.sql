{% macro check_target() %}
    {{ log("schema: " ~ target.schema, info=true) }}
    {{ log("name: " ~ target.name, info=true) }}
    {{ log("database: " ~ target.database, info=true) }}
{% endmacro %}
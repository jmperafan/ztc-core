{% macro check_target() %}

    {# target object — connection & environment #}
    {{ log("target.name: "      ~ target.name,      info=true) }}
    {{ log("target.schema: "    ~ target.schema,    info=true) }}
    {{ log("target.database: "  ~ target.database,  info=true) }}
    {{ log("target.type: "      ~ target.type,      info=true) }}
    {{ log("target.threads: "   ~ target.threads,   info=true) }}
    {{ log("target.user: "      ~ target.user,      info=true) }}

    {# Snowflake-specific target properties #}
    {{ log("target.role: "      ~ target.role,      info=true) }}
    {{ log("target.warehouse: " ~ target.warehouse, info=true) }}
    {{ log("target.account: "   ~ target.account,   info=true) }}

    {# dbt run context #}
    {{ log("dbt_version: "      ~ dbt_version,      info=true) }}
    {{ log("invocation_id: "    ~ invocation_id,    info=true) }}
    {{ log("run_started_at: "   ~ run_started_at,   info=true) }}

    {# execution phase — false during parsing/compilation, true when queries run #}
    {{ log("execute: "          ~ execute,          info=true) }}

{% endmacro %}

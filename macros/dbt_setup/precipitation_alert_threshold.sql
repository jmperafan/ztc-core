{#-
    Environment variable reference for the ZTC project.

    env_var() is available anywhere dbt evaluates Jinja: dbt_project.yml (vars),
    profiles.yml, model SQL, macros, and schema YAML files.

    Syntax:
        env_var('VAR_NAME')               -- required; fails at compile time if unset
        env_var('VAR_NAME', 'default')    -- optional; falls back to the default

    Project-level variables that read from the environment (see dbt_project.yml):
        DBT_START_DATE      Earliest date for historical analysis.  Default: 2022-01-01
        ZTC_OPENING_TIME    Court opening time (HH:MM:SS).          Default: 08:00:00
        ZTC_CLOSING_TIME    Court closing time (HH:MM:SS).          Default: 23:00:00

    Credentials (no default — must be set; loaded from profiles.yml or .env):
        SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD,
        SNOWFLAKE_ROLE, SNOWFLAKE_DATABASE, SNOWFLAKE_WAREHOUSE
-#}

{% macro precipitation_alert_threshold() %}
    {#-
        Returns the precipitation level (mm) above which conditions are flagged as
        unsuitable for outdoor play. Set DBT_PRECIPITATION_ALERT_MM to override.
        Example usage in SQL:
            WHERE precipitation > {{ precipitation_alert_threshold() }}
    -#}
    {{- env_var('DBT_PRECIPITATION_ALERT_MM', '2') -}}
{% endmacro %}

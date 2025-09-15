--macros/get_custom_schema.sql in dbt could
-- This macro tells dbt to use exact schema names without adding username
{% macro generate_schema_name(custom_schema_name, node) -%}
  {{ custom_schema_name | trim }}
{%- endmacro %}
{#-
  Renders the columns declared in dbt sources as a VALUES list, straight from
  the project graph at compile time. Used by audit_schema_drift to compare the
  code contract against the physical INFORMATION_SCHEMA.
-#}
{% macro declared_source_columns(schema_name) -%}
    {%- set rows = [] -%}
    {%- if execute -%}
        {%- for source in graph.sources.values() -%}
            {%- if source.schema | upper == schema_name | upper -%}
                {%- for column_name in source.columns -%}
                    {%- do rows.append(
                        "('" ~ source.schema | upper ~ "', '"
                        ~ source.identifier | upper ~ "', '"
                        ~ column_name | upper ~ "', '"
                        ~ (source.columns[column_name].data_type or '') | upper ~ "')"
                    ) -%}
                {%- endfor -%}
            {%- endif -%}
        {%- endfor -%}
    {%- endif -%}
    {%- if rows | length == 0 -%}
        {%- do rows.append("(null, null, null, null)") -%}
    {%- endif -%}
    select
        column1::varchar as table_schema,
        column2::varchar as table_name,
        column3::varchar as column_name,
        nullif(column4, '')::varchar as declared_data_type
    from values
        {{ rows | join(',\n        ') }}
{%- endmacro %}

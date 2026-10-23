{#-
  Shared Jinja macros for schemachange scripts.
  Import with: {% import "modules/bronze.sql" as bronze %}
-#}

{#- Standard lineage columns appended to every BRONZE landing table. -#}
{% macro metadata_columns() -%}
    _source_file        VARCHAR       COMMENT 'Stage file the row was loaded from',
    _source_row_number  NUMBER(38, 0) COMMENT 'Row number inside the source file',
    _loaded_at          TIMESTAMP_TZ  DEFAULT CURRENT_TIMESTAMP() COMMENT 'Load timestamp, used for source freshness'
{%- endmacro %}

{#- COPY INTO statement that maps CSV positional columns and lineage metadata. -#}
{% macro copy_into(database, table, columns, file_prefix) -%}
COPY INTO {{ database }}.BRONZE.{{ table }} (
    {{ columns | join(', ') }}, _source_file, _source_row_number
)
FROM (
    SELECT
        {% for column in columns -%}
        ${{ loop.index }},
        {% endfor -%}
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @{{ database }}.BRONZE.LANDING_STAGE/{{ file_prefix }}/
)
FILE_FORMAT = (FORMAT_NAME = '{{ database }}.BRONZE.CSV_FORMAT')
ON_ERROR = 'ABORT_STATEMENT'
{%- endmacro %}

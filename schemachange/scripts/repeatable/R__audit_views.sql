-- Repeatable script: operational views over deployment and data quality metadata.
USE SCHEMA {{ database }}.AUDIT;

CREATE OR REPLACE VIEW DEPLOYMENT_HISTORY
COMMENT = 'schemachange migrations applied to this database, newest first.'
AS
SELECT
    version,
    description,
    script,
    script_type,
    status,
    execution_time,
    installed_by,
    installed_on
FROM {{ database }}.SCHEMACHANGE.CHANGE_HISTORY
ORDER BY installed_on DESC;

{% if enable_data_metric_functions | lower == 'true' %}
CREATE OR REPLACE VIEW DATA_METRIC_RESULTS
COMMENT = 'Latest Data Metric Function measurements for BRONZE tables.'
AS
SELECT
    table_schema,
    table_name,
    metric_name,
    ARRAY_TO_STRING(argument_names, ', ') AS column_names,
    value AS metric_value,
    measurement_time
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = '{{ database }}'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY table_schema, table_name, metric_name, column_names
    ORDER BY measurement_time DESC
) = 1;
{% endif %}

-- Ingestion objects: CSV file format and an internal landing stage.
-- Files are uploaded with PUT by ops/load_sample_data.py (or any upstream tool).
USE SCHEMA {{ database }}.BRONZE;

CREATE FILE FORMAT IF NOT EXISTS CSV_FORMAT
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE
    TRIM_SPACE = TRUE
    COMMENT = 'Header-first CSV exported by the storefront.';

CREATE STAGE IF NOT EXISTS LANDING_STAGE
    FILE_FORMAT = CSV_FORMAT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal landing zone, one folder per source table.';

-- Always script: runs on every deployment so privileges converge to this
-- definition, including on freshly cloned pull request databases (clones do
-- not inherit grants on the database object itself).
-- SELECT on GOLD for the reader role is managed by dbt (grants config).
GRANT USAGE ON DATABASE {{ database }} TO ROLE {{ transformer_role }};
GRANT USAGE ON DATABASE {{ database }} TO ROLE {{ reader_role }};

-- BRONZE: read-only for dbt. Re-granted on every run to cover new tables.
GRANT USAGE ON SCHEMA {{ database }}.BRONZE TO ROLE {{ transformer_role }};
GRANT SELECT ON ALL TABLES IN SCHEMA {{ database }}.BRONZE TO ROLE {{ transformer_role }};

-- SILVER / GOLD / AUDIT: dbt builds objects here.
{% for schema in ['SILVER', 'GOLD', 'AUDIT'] %}
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA {{ database }}.{{ schema }} TO ROLE {{ transformer_role }};
{% endfor %}
GRANT SELECT ON ALL VIEWS IN SCHEMA {{ database }}.AUDIT TO ROLE {{ transformer_role }};

GRANT USAGE ON SCHEMA {{ database }}.GOLD TO ROLE {{ reader_role }};

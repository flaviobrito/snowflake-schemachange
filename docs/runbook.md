# Runbook

## 1. Key-pair authentication

The service user authenticates with an RSA key pair. Snowflake is phasing out
password-only sign-in for service users, so no password is ever created.

```bash
mkdir -p keys
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 aes256 -inform PEM -out keys/snowflake_rsa_key.p8
openssl rsa -in keys/snowflake_rsa_key.p8 -pubout -out keys/snowflake_rsa_key.pub
```

- Paste the body of `snowflake_rsa_key.pub` (without the `BEGIN`/`END` lines) into
  `bootstrap/account_setup.sql`.
- Store the content of `snowflake_rsa_key.p8` in the `SNOWFLAKE_PRIVATE_KEY`
  secret and the passphrase in `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`.
- `keys/` is git-ignored.

Rotate without downtime: set `RSA_PUBLIC_KEY_2` on the user, update the secret,
then unset the old key (`ALTER USER SVC_ECOMMERCE_CICD UNSET RSA_PUBLIC_KEY`).

## 2. Account bootstrap (once)

Run `bootstrap/account_setup.sql` as an administrator. It creates:

| Object                       | Purpose                                                    |
| ---------------------------- | ---------------------------------------------------------- |
| `ECOMMERCE_DEPLOYER`         | Owns databases; runs schemachange and clones               |
| `ECOMMERCE_TRANSFORMER`      | Runs dbt (read BRONZE, write SILVER/GOLD/AUDIT)            |
| `ECOMMERCE_READER`           | Read-only GOLD access for BI                               |
| `ECOMMERCE_WH`               | XSMALL warehouse, 60 s auto-suspend, monthly resource monitor |
| `ECOMMERCE_DEV`, `ECOMMERCE_PROD` | Environment databases                                 |
| `SVC_ECOMMERCE_CICD`         | `TYPE = SERVICE` user with key-pair authentication          |

Then run the first deployment from GitHub (**Actions → Deploy → Run workflow**
with *Load sample data* checked), or locally with `make migrate sample-data build`.

On Snowflake Standard edition, skip the Data Metric Function grants and set the
`ENABLE_DATA_METRIC_FUNCTIONS` variable to `false` **before** the first deployment
(`V1.4.0` is a versioned script and runs only once).

## 3. Writing migrations

- **Never edit an applied versioned script.** schemachange records its checksum;
  add a new `V<next>__description.sql` instead.
- Use `IF NOT EXISTS` / `IF EXISTS` so scripts are safe on clones and re-runs.
- Objects that are fully redefined (views, procedures, functions) belong in
  `R__` scripts; privileges belong in `A__grants.sql`.
- Any new or changed BRONZE column must be declared in
  `dbt/models/silver/ecommerce/_ecommerce__sources.yml`, otherwise the
  `assert_no_bronze_schema_drift` test fails the pull request.
- Preview the rendered SQL offline:
  `uv run schemachange render --config-folder schemachange schemachange/scripts/versioned/<file>.sql`

## 4. Rollback

schemachange is forward-only (no down migrations). Options, from least to most invasive:

| Situation                                   | Action                                                                  |
| ------------------------------------------- | ----------------------------------------------------------------------- |
| Bad view/procedure (`R__`)                  | Revert the commit; the repeatable script is re-applied on the next deploy |
| Bad versioned migration, data intact        | Ship a new corrective `V` script (forward fix)                           |
| Dropped or corrupted table                  | `UNDROP TABLE` or `CREATE TABLE ... CLONE ... AT (OFFSET => -3600)` (Time Travel: 7 days in PROD) |
| Deployment broke PROD broadly               | Swap with the pre-deployment backup (below)                              |

Every PROD deployment first refreshes `ECOMMERCE_PROD_PREDEPLOY`, a zero-copy
clone taken immediately before migrating. To restore it:

```sql
USE ROLE ECOMMERCE_DEPLOYER;
ALTER DATABASE ECOMMERCE_PROD SWAP WITH ECOMMERCE_PROD_PREDEPLOY;
-- ECOMMERCE_PROD now holds the pre-deployment state;
-- ECOMMERCE_PROD_PREDEPLOY holds the failed state for investigation.
```

Afterwards, revert the offending commit on `main` so the code matches the
restored change history.

## 5. Pull request environments

`ECOMMERCE_PR_<number>` is cloned from DEV when CI starts and dropped by
`pr-cleanup.yml` when the pull request closes. `ops/manage_database.py` refuses to
drop anything that does not start with `ECOMMERCE_PR_`. Leftovers (for example
after a cancelled run) can be listed with:

```sql
SHOW DATABASES LIKE 'ECOMMERCE_PR_%';
```

## 6. Schema drift alerts

`scheduled.yml` refreshes `AUDIT.AUDIT_SCHEMA_SNAPSHOTS` and
`AUDIT.AUDIT_SCHEMA_DRIFT`, then `ops/check_schema_drift.py` posts every
non-aligned column to `SCHEMA_ALERT_WEBHOOK_URL` and fails the run. Typical causes:

| Status                | Meaning                                         | Fix                                    |
| --------------------- | ----------------------------------------------- | -------------------------------------- |
| `undeclared_in_dbt`   | Column exists in Snowflake but not in sources   | Declare it, or remove the manual change via a migration |
| `missing_in_database` | Declared in sources but not in Snowflake        | Add the migration, or remove the declaration |
| `type_mismatch`       | Types differ                                    | Align the declaration or migrate the column |

# Data quality

Checks are layered so that problems are caught as close to the source as
possible, while raw data is never silently discarded.

| Layer  | Mechanism                         | Severity | Where                                      |
| ------ | --------------------------------- | -------- | ------------------------------------------ |
| BRONZE | Snowflake Data Metric Functions   | monitor  | `V1.4.0__create_data_quality_metrics.sql`  |
| BRONZE | dbt source tests and freshness    | warn     | `_ecommerce__sources.yml`                  |
| SILVER | dbt data tests                    | error*   | `_ecommerce__models.yml`                   |
| GOLD   | Contracts, data and unit tests    | error*   | `_core__models.yml`, `_finance__models.yml` |
| AUDIT  | Schema drift                      | error    | `audit_schema_drift`, `assert_no_bronze_schema_drift` |

\* A few business heuristics are `warn` (see below). Failing rows of every test
are stored in the `AUDIT` schema, one table per test.

## Snowflake Data Metric Functions (BRONZE)

Scheduled with `TRIGGER_ON_CHANGES`, so they run whenever a load changes the table.
Latest values: `select * from AUDIT.DATA_METRIC_RESULTS`.

| Table         | Metric                                       |
| ------------- | -------------------------------------------- |
| `CUSTOMERS`   | `NULL_COUNT(customer_id)`, `DUPLICATE_COUNT(customer_id)`, `INVALID_EMAIL_COUNT(email)` |
| `ORDERS`      | `NULL_COUNT(customer_id)`, `DUPLICATE_COUNT(order_id)`, `FRESHNESS(_loaded_at)` |
| `ORDER_ITEMS` | `DUPLICATE_COUNT(order_item_id)`, `NEGATIVE_VALUE_COUNT(unit_price)` |
| `PAYMENTS`    | `DUPLICATE_COUNT(payment_id)`, `NEGATIVE_VALUE_COUNT(amount)` |

## dbt tests

| Category               | Examples                                                                 |
| ---------------------- | ------------------------------------------------------------------------ |
| Freshness              | Sources warn after 24 h and error after 72 h; `dbt_utils.recency` on `fct_orders` |
| Volume                 | `expect_table_row_count_to_be_between` (source), `expect_table_row_count_to_equal_other_table` (SILVER vs GOLD) |
| Uniqueness             | `unique`, `dbt_utils.unique_combination_of_columns`                       |
| Completeness           | `not_null`, contract `not_null` constraints                               |
| Referential integrity  | `relationships` on every foreign key, source to GOLD                      |
| Validity               | `accepted_values`, `dbt_utils.accepted_range`, `expect_column_values_to_match_regex`, custom `is_valid_email`, `non_negative` |
| Business rules         | `order_total = items - discount + shipping`, `unit_cost <= unit_price`, delivered orders are paid, payments do not exceed totals, revenue reconciles between `fct_orders` and `agg_daily_revenue` |
| Logic (unit tests)     | `fct_orders` totals and revenue flag; `dim_customers` segmentation        |
| Structure              | Enforced contracts on all GOLD models; schema drift between BRONZE and sources |

## Warn vs error

- **BRONZE source tests warn.** Raw duplicates and invalid emails are expected and
  are handled in SILVER (deduplication, `is_email_valid`).
- **SILVER and GOLD tests error**, except heuristics that can legitimately occur
  (cost above price, discount above items amount, orders without items, stale
  data, payments above total) which warn.
- Run `python -m ops.generate_sample_data --inject-anomalies` and load it into a
  development database to see the error-level tests fail.

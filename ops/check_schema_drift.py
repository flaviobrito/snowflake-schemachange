"""Report BRONZE schema drift (AUDIT.AUDIT_SCHEMA_DRIFT) to Slack or Microsoft Teams.

The view is built by dbt; this script only reads it. Without a webhook the
report is printed, which keeps the script useful locally and in CI logs.

Example:
    python -m ops.check_schema_drift --webhook-url "$SCHEMA_ALERT_WEBHOOK_URL" --fail-on-drift
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import urllib.request
from dataclasses import dataclass

from ops.connection import connect, require_env

logger = logging.getLogger(__name__)

STATUS_LABELS = {
    "missing_in_database": "declared in dbt but missing in Snowflake",
    "undeclared_in_dbt": "exists in Snowflake but is not declared in dbt sources",
    "type_mismatch": "data type differs between Snowflake and dbt",
}


@dataclass(frozen=True)
class Drift:
    table_name: str
    column_name: str
    status: str
    physical_data_type: str | None
    declared_data_type: str | None


def fetch_drift(database: str) -> list[Drift]:
    query = f"""
        select table_name, column_name, drift_status, physical_data_type, declared_data_type
        from {database}.AUDIT.AUDIT_SCHEMA_DRIFT
        where drift_status != 'aligned'
        order by table_name, column_name
    """
    with connect(database=database, role=os.environ.get("DBT_SNOWFLAKE_ROLE")) as conn:
        return [Drift(*row) for row in conn.cursor().execute(query).fetchall()]


def build_message(database: str, drifts: list[Drift]) -> str:
    lines = [f"Schema drift detected in {database}.BRONZE ({len(drifts)} column(s))"]
    for drift in drifts:
        detail = STATUS_LABELS.get(drift.status, drift.status)
        if drift.status == "type_mismatch":
            detail += f" ({drift.physical_data_type} vs {drift.declared_data_type})"
        lines.append(f"- {drift.table_name}.{drift.column_name}: {detail}")
    if run_url := os.environ.get("GITHUB_RUN_URL"):
        lines.append(f"Run: {run_url}")
    return "\n".join(lines)


def send_webhook(url: str, text: str) -> None:
    # {"text": ...} is accepted by Slack incoming webhooks and Teams workflow webhooks.
    request = urllib.request.Request(
        url,
        data=json.dumps({"text": text}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        logger.info("Webhook responded with HTTP %s", response.status)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--webhook-url", default=os.environ.get("SCHEMA_ALERT_WEBHOOK_URL"))
    parser.add_argument("--fail-on-drift", action="store_true")
    args = parser.parse_args()

    database = require_env("SNOWFLAKE_DATABASE")
    drifts = fetch_drift(database)
    if not drifts:
        logger.info("No schema drift in %s.BRONZE", database)
        return 0

    message = build_message(database, drifts)
    print(message)
    if args.webhook_url:
        send_webhook(args.webhook_url, message)
    return 1 if args.fail_on_drift else 0


if __name__ == "__main__":
    sys.exit(main())

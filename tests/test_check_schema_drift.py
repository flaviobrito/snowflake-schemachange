import pytest

from ops.check_schema_drift import Drift, build_message
from ops.connection import quote_identifier
from ops.manage_database import drop_database


def test_message_lists_every_drifted_column(monkeypatch):
    monkeypatch.delenv("GITHUB_RUN_URL", raising=False)
    message = build_message(
        "ECOMMERCE_PROD",
        [
            Drift("CUSTOMERS", "LOYALTY_TIER", "undeclared_in_dbt", "TEXT", None),
            Drift("ORDERS", "AMOUNT", "type_mismatch", "TEXT", "NUMBER"),
        ],
    )
    assert message.splitlines() == [
        "Schema drift detected in ECOMMERCE_PROD.BRONZE (2 column(s))",
        "- CUSTOMERS.LOYALTY_TIER: exists in Snowflake but is not declared in dbt sources",
        "- ORDERS.AMOUNT: data type differs between Snowflake and dbt (TEXT vs NUMBER)",
    ]


def test_message_links_the_ci_run(monkeypatch):
    monkeypatch.setenv("GITHUB_RUN_URL", "https://github.com/org/repo/actions/runs/1")
    message = build_message(
        "ECOMMERCE_DEV", [Drift("ORDERS", "X", "missing_in_database", None, "TEXT")]
    )
    assert message.endswith("Run: https://github.com/org/repo/actions/runs/1")


@pytest.mark.parametrize("name", ["ECOMMERCE_PR_1; DROP DATABASE X", "1ABC", "a-b"])
def test_identifier_validation_rejects_unsafe_names(name):
    with pytest.raises(ValueError):
        quote_identifier(name)


@pytest.mark.parametrize(
    "database", ["ECOMMERCE_PROD", "ECOMMERCE_DEV", "ECOMMERCE_PROD_PREDEPLOY"]
)
def test_only_pull_request_databases_can_be_dropped(database):
    with pytest.raises(ValueError, match="Refusing to drop"):
        drop_database(database)

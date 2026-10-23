"""Snowflake connection built from the same SNOWFLAKE_* variables used by schemachange and dbt."""

from __future__ import annotations

import os

import snowflake.connector
from snowflake.connector import SnowflakeConnection


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Environment variable {name} is required")
    return value


def connect(database: str | None = None, role: str | None = None) -> SnowflakeConnection:
    """Open a key-pair authenticated connection."""
    params = {
        "account": require_env("SNOWFLAKE_ACCOUNT"),
        "user": require_env("SNOWFLAKE_USER"),
        "authenticator": "SNOWFLAKE_JWT",
        "private_key_file": require_env("SNOWFLAKE_PRIVATE_KEY_FILE"),
        "role": role or os.environ.get("SNOWFLAKE_ROLE", "ECOMMERCE_DEPLOYER"),
        "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "ECOMMERCE_WH"),
        "session_parameters": {"QUERY_TAG": "ops-ecommerce"},
    }
    if passphrase := os.environ.get("SNOWFLAKE_PRIVATE_KEY_FILE_PWD"):
        params["private_key_file_pwd"] = passphrase
    if database := database or os.environ.get("SNOWFLAKE_DATABASE"):
        params["database"] = database
    return snowflake.connector.connect(**params)


def quote_identifier(name: str) -> str:
    """Validate an unquoted Snowflake identifier (letters, digits, underscore)."""
    if not name.replace("_", "").isalnum() or name[0].isdigit():
        raise ValueError(f"Invalid identifier: {name!r}")
    return name.upper()

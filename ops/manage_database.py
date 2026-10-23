"""Zero-copy clone management for pull request environments and pre-deploy backups.

Examples:
    python -m ops.manage_database clone --source ECOMMERCE_DEV --target ECOMMERCE_PR_42
    python -m ops.manage_database drop --target ECOMMERCE_PR_42
"""

from __future__ import annotations

import argparse
import logging

from ops.connection import connect, quote_identifier

logger = logging.getLogger(__name__)

# Only disposable databases may ever be dropped by automation.
DROPPABLE_PREFIXES = ("ECOMMERCE_PR_",)


def clone_database(source: str, target: str) -> None:
    source, target = quote_identifier(source), quote_identifier(target)
    with connect() as conn:
        conn.cursor().execute(
            f"CREATE OR REPLACE DATABASE {target} CLONE {source} "
            f"COMMENT = 'Zero-copy clone of {source} managed by CI'"
        )
    logger.info("Cloned %s into %s", source, target)


def drop_database(target: str) -> None:
    target = quote_identifier(target)
    if not target.startswith(DROPPABLE_PREFIXES):
        raise ValueError(f"Refusing to drop {target}: only {DROPPABLE_PREFIXES} can be dropped")
    with connect() as conn:
        conn.cursor().execute(f"DROP DATABASE IF EXISTS {target}")
    logger.info("Dropped %s", target)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    clone = subparsers.add_parser("clone")
    clone.add_argument("--source", required=True)
    clone.add_argument("--target", required=True)
    drop = subparsers.add_parser("drop")
    drop.add_argument("--target", required=True)
    args = parser.parse_args()

    if args.command == "clone":
        clone_database(args.source, args.target)
    else:
        drop_database(args.target)


if __name__ == "__main__":
    main()

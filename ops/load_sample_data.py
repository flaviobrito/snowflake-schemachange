"""Upload generated CSV files to the BRONZE landing stage and load them.

Example:
    python -m ops.load_sample_data --input-dir data/sample
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

from ops.connection import connect, require_env
from ops.generate_sample_data import COLUMNS

logger = logging.getLogger(__name__)


def load(input_dir: Path) -> None:
    database = require_env("SNOWFLAKE_DATABASE")
    with connect(database=database) as conn:
        cursor = conn.cursor()
        for table in COLUMNS:
            files = sorted((input_dir / table).glob("*.csv"))
            if not files:
                logger.warning("No files for %s in %s", table, input_dir / table)
                continue
            for path in files:
                cursor.execute(
                    f"PUT 'file://{path.resolve().as_posix()}' "
                    f"@{database}.BRONZE.LANDING_STAGE/{table}/ "
                    "AUTO_COMPRESS = TRUE OVERWRITE = FALSE"
                )
                logger.info("Uploaded %s", path.name)
        result = cursor.execute(f"CALL {database}.BRONZE.LOAD_FROM_STAGE()").fetchone()
        logger.info("%s", result[0] if result else "Load finished")


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path("data/sample"))
    load(parser.parse_args().input_dir)


if __name__ == "__main__":
    main()

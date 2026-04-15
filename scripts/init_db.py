#!/usr/bin/env python3

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB_PATH = ROOT_DIR / "data" / "waferdb.sqlite"
SCHEMA_PATH = ROOT_DIR / "db" / "schema.sql"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create the WaferDb SQLite database from the checked-in schema."
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=DEFAULT_DB_PATH,
        help=f"Output SQLite file (default: {DEFAULT_DB_PATH})",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Replace the target database file if it already exists.",
    )
    return parser.parse_args()


def initialize_database(db_path: Path, replace: bool) -> None:
    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")
    db_path = db_path.expanduser()

    if db_path.exists():
        if not replace:
            raise FileExistsError(
                f"{db_path} already exists. Re-run with --replace to overwrite it."
            )
        db_path.unlink()

    db_path.parent.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(db_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON;")
        connection.executescript(schema_sql)


def main() -> int:
    args = parse_args()

    try:
        initialize_database(args.db, args.replace)
    except FileExistsError as exc:
        print(exc)
        return 1

    print(f"Initialized WaferDb at {args.db}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


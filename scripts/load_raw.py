#!/usr/bin/env python3
"""Bulk-load the prepared case CSV into PostgreSQL without changing the file."""

from __future__ import annotations

import csv
import gzip
import hashlib
import json
import os
from pathlib import Path

import psycopg2
from psycopg2 import sql


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_PATH = PROJECT_ROOT / "data" / "raw_triage_case_rows.csv"
RAW_GZIP_PATH = PROJECT_ROOT / "data" / "raw_triage_case_rows.csv.gz"
MANIFEST_PATH = PROJECT_ROOT / "seeds" / "raw_source_manifest.csv"
SCHEMA = "ss_raw"
TABLE = "raw_triage_case_rows"
COLUMNS = [
    "patient_id",
    "age",
    "gender",
    "time_since_bite_min",
    "heart_rate_bpm",
    "blood_pressure_systolic",
    "local_swelling",
    "muscle_paralysis_present",
    "blood_coagulation_failure",
    "bite_source_target",
    "bite_timestamp",
    "arrival_timestamp",
    "province",
    "triage_level",
    "bite_position",
    "source_row_number",
]


def expected_row_count() -> tuple[int, dict[str, str]]:
    with MANIFEST_PATH.open("r", newline="", encoding="utf-8-sig") as manifest_file:
        reader = csv.DictReader(manifest_file)
        rows = list(reader)
    if len(rows) != 1:
        raise ValueError(f"Expected one manifest row, found {len(rows)}")
    row = rows[0]
    count = int(row["source_row_count"])
    if count < 1:
        raise ValueError(f"Manifest row count must be positive, found {count}")
    return count, row


def verify_header(path: Path) -> None:
    raw_file = open_raw_csv(path)
    with raw_file:
        header = next(csv.reader(raw_file), None)
    if header != COLUMNS:
        raise ValueError(
            "Unexpected prepared CSV header. Expected exactly: " + ", ".join(COLUMNS)
        )


def prepared_path() -> Path:
    """Choose the local prepared CSV, falling back to the bundled gzip file."""
    if RAW_PATH.is_file():
        return RAW_PATH
    if RAW_GZIP_PATH.is_file():
        return RAW_GZIP_PATH
    raise FileNotFoundError(
        f"Prepared CSV not found: expected {RAW_PATH} or {RAW_GZIP_PATH}"
    )


def open_raw_csv(path: Path):
    """Open prepared CSV content, transparently decompressing the bundled gzip."""
    if path.suffix == ".gz":
        return gzip.open(path, "rt", newline="", encoding="utf-8-sig")
    return path.open("r", newline="", encoding="utf-8-sig")


def prepared_content_sha256(path: Path) -> str:
    """Hash the CSV bytes, so compression does not affect the manifest checksum."""
    digest = hashlib.sha256()
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_prepared_checksum(manifest: dict[str, str], path: Path) -> None:
    expected = manifest.get("prepared_file_sha256", "")
    if len(expected) != 64 or any(char not in "0123456789abcdef" for char in expected):
        raise ValueError("Manifest prepared_file_sha256 must be a lowercase SHA-256 hex digest")
    actual = prepared_content_sha256(path)
    if actual != expected:
        raise ValueError(
            "Prepared CSV SHA-256 does not match the source manifest: "
            f"expected {expected}, found {actual}"
        )


def load() -> dict[str, object]:
    if not MANIFEST_PATH.is_file():
        raise FileNotFoundError(f"Source manifest not found: {MANIFEST_PATH}")

    expected, manifest = expected_row_count()
    raw_path = prepared_path()
    verify_prepared_checksum(manifest, raw_path)
    verify_header(raw_path)

    connection = psycopg2.connect(
        host="postgres",
        port=5432,
        dbname=os.getenv("POSTGRES_DB", "silent_sting_dw"),
        user=os.getenv("POSTGRES_USER", "dw_user"),
        password=os.getenv("POSTGRES_PASSWORD", "dw_pass"),
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql.SQL("CREATE SCHEMA IF NOT EXISTS {} ").format(sql.Identifier(SCHEMA)))
            cursor.execute(
                sql.SQL(
                    """
                    CREATE TABLE IF NOT EXISTS {}.{} (
                        patient_id text,
                        age text,
                        gender text,
                        time_since_bite_min text,
                        heart_rate_bpm text,
                        blood_pressure_systolic text,
                        local_swelling text,
                        muscle_paralysis_present text,
                        blood_coagulation_failure text,
                        bite_source_target text,
                        bite_timestamp text,
                        arrival_timestamp text,
                        province text,
                        triage_level text,
                        bite_position text,
                        source_row_number bigint NOT NULL
                    )
                    """
                ).format(sql.Identifier(SCHEMA), sql.Identifier(TABLE))
            )
            cursor.execute(
                sql.SQL("TRUNCATE TABLE {}.{}").format(
                    sql.Identifier(SCHEMA), sql.Identifier(TABLE)
                )
            )
            copy_command = sql.SQL(
                "COPY {}.{} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')"
            ).format(
                sql.Identifier(SCHEMA),
                sql.Identifier(TABLE),
                sql.SQL(", ").join(map(sql.Identifier, COLUMNS)),
            )
            with open_raw_csv(raw_path) as raw_file:
                cursor.copy_expert(copy_command.as_string(connection), raw_file)
            cursor.execute(
                sql.SQL("SELECT count(*) FROM {}.{}").format(
                    sql.Identifier(SCHEMA), sql.Identifier(TABLE)
                )
            )
            loaded = int(cursor.fetchone()[0])
            if loaded != expected:
                raise ValueError(
                    f"Loaded {loaded:,} raw rows but the manifest expects {expected:,}"
                )
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()

    return {
        "table": f"{SCHEMA}.{TABLE}",
        "source_file_name": manifest["source_file_name"],
        "source_file_sha256": manifest["source_file_sha256"],
        "loaded_rows": loaded,
    }


if __name__ == "__main__":
    print(json.dumps(load(), ensure_ascii=False))

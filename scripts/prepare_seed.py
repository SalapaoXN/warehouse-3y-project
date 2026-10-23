#!/usr/bin/env python3
"""Prepare a reproducible raw CSV load file without modifying the source CSV."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path


SOURCE_COLUMNS = [
    "Patient_ID",
    "Age",
    "Gender",
    "Time_Since_Bite_Min",
    "Heart_Rate_BPM",
    "Blood_Pressure_Systolic",
    "Local_Swelling",
    "Muscle_Paralysis_Present",
    "Blood_Coagulation_Failure",
    "Bite_Source_Target",
    "Bite_Timestamp",
    "Arrival_Timestamp",
    "Province",
    "Triage_Level",
    "Bite_Position",
]

OUTPUT_COLUMNS = [
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
]

COLUMN_MAP = dict(zip(SOURCE_COLUMNS, OUTPUT_COLUMNS))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_atomic_csv(path: Path, fieldnames: list[str], rows) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    os.close(descriptor)
    temporary_path = Path(temporary_name)
    try:
        with temporary_path.open("w", newline="", encoding="utf-8") as output:
            writer = csv.DictWriter(output, fieldnames=fieldnames, extrasaction="raise")
            writer.writeheader()
            writer.writerows(rows)
        os.replace(temporary_path, path)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise


def prepare(input_path: Path, seed_path: Path, manifest_path: Path) -> None:
    if not input_path.is_file():
        raise FileNotFoundError(f"Input CSV not found: {input_path}")

    source_hash = sha256_file(input_path)
    if seed_path.exists() and manifest_path.exists():
        try:
            existing = next(csv.DictReader(manifest_path.open(encoding="utf-8")))
        except (OSError, StopIteration, csv.Error):
            existing = {}
        if (
            existing.get("source_file_sha256") == source_hash
            and existing.get("prepared_file_sha256") == sha256_file(seed_path)
        ):
            print(f"Seed already matches source SHA-256 {source_hash}; no rewrite needed.")
            return

    row_count = 0

    def rows():
        nonlocal row_count
        with input_path.open("r", newline="", encoding="utf-8-sig") as source:
            reader = csv.DictReader(source)
            if reader.fieldnames is None or set(reader.fieldnames) != set(SOURCE_COLUMNS):
                raise ValueError(
                    "Unexpected source columns. Expected exactly: "
                    + ", ".join(SOURCE_COLUMNS)
                )
            for row_count, source_row in enumerate(reader, start=1):
                yield {
                    **{
                        target: source_row[source_name]
                        for source_name, target in COLUMN_MAP.items()
                    },
                }

    write_atomic_csv(seed_path, OUTPUT_COLUMNS, rows())
    prepared_hash = sha256_file(seed_path)
    manifest = [
        {
            "source_file_name": input_path.name,
            "source_file_sha256": source_hash,
            "source_row_count": row_count,
            "prepared_file_sha256": prepared_hash,
            "prepared_at_utc": datetime.now(timezone.utc).isoformat(),
        }
    ]
    write_atomic_csv(
        manifest_path,
        [
            "source_file_name",
            "source_file_sha256",
            "source_row_count",
            "prepared_file_sha256",
            "prepared_at_utc",
        ],
        manifest,
    )
    print(
        json.dumps(
            {
                "seed_path": str(seed_path),
                "manifest_path": str(manifest_path),
                "source_file_name": input_path.name,
                "source_file_sha256": source_hash,
                "source_row_count": row_count,
                "prepared_file_sha256": prepared_hash,
            },
            ensure_ascii=False,
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Original source CSV")
    parser.add_argument(
        "--seed",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "data" / "raw_triage_case_rows.csv",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "data" / "raw_source_manifest.csv",
    )
    args = parser.parse_args()
    prepare(args.input, args.seed, args.manifest)


if __name__ == "__main__":
    main()

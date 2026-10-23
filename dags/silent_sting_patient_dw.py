"""Manually triggered local orchestration for the Silent Sting patient-grain DW."""

from datetime import timedelta
from pathlib import Path
import os
import subprocess
import sys
import time

import psycopg2
from airflow.sdk import dag, task
from pendulum import datetime


PROJECT_DIR = Path("/opt/airflow/project")


@dag(
    dag_id="silent_sting_patient_dw",
    description="Load the current snapshot and build/test the patient-grain warehouse with dbt.",
    schedule=None,
    start_date=datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=1)},
    tags=["silent-sting", "dbt", "local-lab"],
)
def silent_sting_patient_dw():
    @task
    def wait_for_postgres():
        last_error = None
        for attempt in range(30):
            try:
                with psycopg2.connect(
                    host="postgres",
                    port=5432,
                    dbname=os.getenv("POSTGRES_DB", "silent_sting_dw"),
                    user=os.getenv("POSTGRES_USER", "dw_user"),
                    password=os.getenv("POSTGRES_PASSWORD", "dw_pass"),
                    connect_timeout=5,
                ):
                    return "PostgreSQL is ready"
            except psycopg2.OperationalError as exc:
                last_error = exc
                time.sleep(2)
        raise RuntimeError("PostgreSQL did not become ready") from last_error

    @task
    def load_raw_snapshot():
        subprocess.run(
            [sys.executable, "scripts/load_raw.py"],
            cwd=PROJECT_DIR,
            check=True,
        )

    @task
    def build_dbt_warehouse():
        subprocess.run(
            [
                "/home/airflow/dbt-venv/bin/dbt", "build",
                "--project-dir", str(PROJECT_DIR),
                "--profiles-dir", str(PROJECT_DIR),
                "--target-path", "/tmp/silent-sting-dbt-target",
                "--log-path", "/tmp/silent-sting-dbt-logs",
            ],
            cwd=PROJECT_DIR,
            check=True,
        )

    ready = wait_for_postgres()
    loaded = load_raw_snapshot()
    built = build_dbt_warehouse()
    ready >> loaded >> built


silent_sting_patient_dw()

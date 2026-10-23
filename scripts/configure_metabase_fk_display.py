"""Configure human-readable FK values for the Silent Sting fact table."""

import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


BASE_URL = os.environ.get("METABASE_URL", "http://localhost:23000").rstrip("/")
ADMIN_EMAIL = os.environ.get("METABASE_ADMIN_EMAIL", "admin@example.com")
ADMIN_PASSWORD = os.environ.get("METABASE_ADMIN_PASSWORD", "SilentStingDemo2026!")
DATABASE_NAME = "silent_sting_dw"
SCHEMA_NAME = "ss_dw"
FACT_TABLE = "fact_bite_triage"

MAPPINGS = {
    "bite_date_key": ("dim_date", "full_date", "Bite Date"),
    "arrival_date_key": ("dim_date", "full_date", "Arrival Date"),
    "location_key": ("dim_location", "province_name", "Province"),
    "bite_source_key": ("dim_bite_source", "bite_source_name", "Bite Source"),
    "bite_position_key": ("dim_bite_position", "bite_position_name", "Bite Position"),
    "symptom_profile_key": (
        "dim_symptom_profile",
        "symptom_profile_label",
        "Symptom Profile",
    ),
    "triage_key": ("dim_triage", "triage_level_label", "Triage Level"),
}


def request_json(path, *, session_id=None, payload=None):
    headers = {"Content-Type": "application/json"}
    if session_id:
        headers["X-Metabase-Session"] = session_id
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    request = Request(f"{BASE_URL}{path}", data=data, headers=headers)
    try:
        with urlopen(request, timeout=30) as response:
            content = response.read()
            return json.loads(content) if content else None
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Metabase API {path} failed ({error.code}): {detail}") from None
    except URLError as error:
        raise RuntimeError(f"Cannot reach Metabase at {BASE_URL}: {error.reason}") from None


def one(items, description):
    matches = list(items)
    if len(matches) != 1:
        raise RuntimeError(f"Expected one {description}, found {len(matches)}")
    return matches[0]


def main():
    session = request_json(
        "/api/session",
        payload={"username": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    session_id = session.get("id")
    if not session_id:
        raise RuntimeError("Metabase login did not return a session")

    databases = request_json("/api/database", session_id=session_id).get("data", [])
    database = one(
        (item for item in databases if item.get("name") == DATABASE_NAME),
        f"database named {DATABASE_NAME!r}",
    )
    tables = request_json(
        f"/api/table?db_id={database['id']}", session_id=session_id
    )
    fact = one(
        (
            item
            for item in tables
            if item.get("schema") == SCHEMA_NAME and item.get("name") == FACT_TABLE
        ),
        f"table {SCHEMA_NAME}.{FACT_TABLE}",
    )
    fact_fields = request_json(
        f"/api/table/{fact['id']}/query_metadata", session_id=session_id
    ).get("fields", [])
    fields_by_name = {field["name"]: field for field in fact_fields}

    target_fields = {}
    for dim_table, display_field, _ in MAPPINGS.values():
        if dim_table in target_fields:
            continue
        dimension = one(
            (
                item
                for item in tables
                if item.get("schema") == SCHEMA_NAME and item.get("name") == dim_table
            ),
            f"table {SCHEMA_NAME}.{dim_table}",
        )
        dimension_fields = request_json(
            f"/api/table/{dimension['id']}/query_metadata", session_id=session_id
        ).get("fields", [])
        target_fields[dim_table] = {field["name"]: field for field in dimension_fields}

    for fact_field_name, (dim_table, display_field_name, mapping_name) in MAPPINGS.items():
        fact_field = fields_by_name.get(fact_field_name)
        target_field = target_fields[dim_table].get(display_field_name)
        if fact_field is None or target_field is None:
            raise RuntimeError(
                f"Missing field for mapping {fact_field_name} -> "
                f"{dim_table}.{display_field_name}; sync the schema and run dbt build first"
            )
        if not fact_field.get("fk_target_field_id"):
            raise RuntimeError(
                f"Metabase has not detected the FK for {fact_field_name}; "
                "sync the database schema first"
            )
        request_json(
            f"/api/field/{fact_field['id']}/dimension",
            session_id=session_id,
            payload={
                "type": "external",
                "name": mapping_name,
                "human_readable_field_id": target_field["id"],
            },
        )
        print(f"{fact_field_name} -> {mapping_name}")

    print("Metabase FK display values are configured.")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, RuntimeError, ValueError) as error:
        raise SystemExit(str(error)) from None

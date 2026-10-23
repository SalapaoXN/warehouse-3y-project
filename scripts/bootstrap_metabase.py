"""Create the local demo admin on a fresh Metabase instance."""

import json
import os
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


BASE_URL = os.environ.get("METABASE_URL", "http://metabase:3000").rstrip("/")
ADMIN_EMAIL = os.environ.get("METABASE_ADMIN_EMAIL", "admin@example.com")
ADMIN_FIRST_NAME = os.environ.get("METABASE_ADMIN_FIRST_NAME", "Admin")
ADMIN_LAST_NAME = os.environ.get("METABASE_ADMIN_LAST_NAME", "User")
ADMIN_PASSWORD = os.environ.get("METABASE_ADMIN_PASSWORD", "")


def get_json(path):
    with urlopen(f"{BASE_URL}{path}", timeout=10) as response:
        return json.load(response)


def post_json(path, payload):
    body = json.dumps(payload).encode("utf-8")
    request = Request(
        f"{BASE_URL}{path}",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(request, timeout=20) as response:
        return json.load(response)


def main():
    if not ADMIN_PASSWORD:
        raise SystemExit("METABASE_ADMIN_PASSWORD is not set")

    deadline = time.monotonic() + 300
    while True:
        try:
            health = get_json("/api/health")
            if health.get("status") == "ok":
                break
        except (HTTPError, URLError, TimeoutError, OSError, ValueError):
            pass

        if time.monotonic() >= deadline:
            raise SystemExit("Metabase did not become healthy within 5 minutes")
        time.sleep(5)

    properties = get_json("/api/session/properties")
    if properties.get("has-user-setup"):
        print("Metabase already has an admin; leaving the existing account unchanged.")
        return

    setup_token = properties.get("setup-token")
    if not setup_token:
        raise SystemExit("Metabase is not set up, but no setup token was available")

    try:
        post_json(
            "/api/setup",
            {
                "token": setup_token,
                "user": {
                    "first_name": ADMIN_FIRST_NAME,
                    "last_name": ADMIN_LAST_NAME,
                    "email": ADMIN_EMAIL,
                    "password": ADMIN_PASSWORD,
                },
                "prefs": {"site_name": "Silent Sting Data Warehouse"},
            },
        )
    except HTTPError as error:
        raise SystemExit(
            f"Metabase admin setup failed (HTTP {error.code}); check the configured credentials."
        ) from None

    print(f"Created the first Metabase admin: {ADMIN_EMAIL}")


if __name__ == "__main__":
    main()

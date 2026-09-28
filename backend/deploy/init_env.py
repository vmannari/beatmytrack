"""Create a private, ignored deployment configuration without printing secrets."""

import os
import secrets
from pathlib import Path


def main() -> None:
    destination = Path(__file__).resolve().parent / ".env"
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
        output.write(
            "COMPOSE_PROJECT_NAME=bmt\n"
            f"POSTGRES_PASSWORD={secrets.token_hex(32)}\n"
            f"BMT_DB_PASSWORD={secrets.token_hex(32)}\n"
            "BMT_PUBLIC_BASE_URL=https://race.example.com\n"
            "BMT_GOOGLE_CLIENT_IDS=\nBMT_PORT=8080\nBMT_TRUSTED_PROXY_IPS=127.0.0.1\nGODOT_SHA256=\n"
            "BMT_IMAGE=bmt-backend:local\n"
        )
    print(
        f"Created {destination}. Set the HTTPS origin, Google client IDs and verified Godot SHA256 before deployment."
    )


if __name__ == "__main__":
    main()

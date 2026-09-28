import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    environment: str = "production"
    dev_auth_enabled: bool = False
    dev_auth_key: str = ""
    database_url: str = "postgresql+psycopg://bmt@localhost/bmt"
    public_base_url: str = "http://localhost:8080"
    object_dir: str = "./var/objects"
    google_client_ids: tuple[str, ...] = field(default_factory=tuple)
    godot_bin: str = ""
    game_project: str = str(Path(__file__).resolve().parents[2] / "game")
    verifier_timeout_seconds: int = 90
    job_lease_seconds: int = 240
    max_job_attempts: int = 3
    access_ttl_seconds: int = 900
    refresh_ttl_seconds: int = 2592000
    max_body_bytes: int = 8 * 1024 * 1024
    rate_limit_per_minute: int = 600
    auth_limit_per_minute: int = 30
    write_limit_per_minute: int = 90

    def __post_init__(self):
        for name in (
            "verifier_timeout_seconds",
            "job_lease_seconds",
            "max_job_attempts",
            "access_ttl_seconds",
            "refresh_ttl_seconds",
            "max_body_bytes",
            "rate_limit_per_minute",
            "auth_limit_per_minute",
            "write_limit_per_minute",
        ):
            value = getattr(self, name)
            if type(value) is not int or value <= 0:
                raise ValueError(f"BMT_{name.upper()} must be a positive integer")
        if self.max_body_bytes > 8 * 1024 * 1024:
            raise ValueError("BMT_MAX_BODY_BYTES cannot exceed the 8 MiB storage/verifier limit")
        # A cold worker can run an engine version probe (10s), manifest process
        # and replay process, followed by database finalization (15s bound).
        if self.job_lease_seconds <= 2 * self.verifier_timeout_seconds + 25:
            raise ValueError("Job lease must exceed twice the verifier timeout plus 25 seconds")
        if self.environment not in ("production", "development", "test"):
            raise ValueError("Invalid BMT_ENVIRONMENT")
        if self.dev_auth_enabled and (self.environment != "development" or len(self.dev_auth_key) < 32):
            raise ValueError(
                "Development auth requires development environment and a secret of at least 32 characters"
            )

    @classmethod
    def from_env(cls):
        defaults = cls()
        values = {}
        for name in cls.__dataclass_fields__:
            raw = os.environ.get("BMT_" + name.upper())
            if raw is None:
                continue
            default = getattr(defaults, name)
            if name == "google_client_ids":
                values[name] = tuple(x.strip() for x in raw.split(",") if x.strip())
            elif isinstance(default, bool):
                if raw.lower() not in ("true", "false"):
                    raise ValueError("Boolean settings must be true or false")
                values[name] = raw.lower() == "true"
            elif isinstance(default, int):
                values[name] = int(raw)
            else:
                values[name] = raw
        result = cls(**values)
        if not result.database_url.startswith("postgresql+psycopg://"):
            raise ValueError(
                "Production requires PostgreSQL; SQLite is available only through test injection"
            )
        return result

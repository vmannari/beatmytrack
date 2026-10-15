import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    admin_owner_key: str = ""
    admin_analyst_key: str = ""
    environment: str = "production"
    dev_auth_enabled: bool = False
    test_drivers_enabled: bool = False
    test_driver_api_url: str = ""
    purchase_simulation_enabled: bool = False
    telemetry_enabled: bool = False
    client_quality_enabled: bool = False
    privacy_developer_name: str = "[Developer name — to be confirmed]"
    privacy_contact_email: str = ""
    privacy_backup_days: int = 30
    privacy_purchase_days: int = 365
    telemetry_client_backlog: int = 50000
    telemetry_processor_batch: int = 500
    telemetry_raw_days: int = 7
    telemetry_fact_days: int = 180
    dev_auth_key: str = ""
    database_url: str = "postgresql+psycopg://bmt@localhost/bmt"
    public_base_url: str = "http://localhost:8080"
    android_app_link_package: str = "org.circuit01.handlinglab"
    android_app_link_certificates: tuple[str, ...] = field(default_factory=tuple)
    object_dir: str = "./var/objects"
    google_client_ids: tuple[str, ...] = field(default_factory=tuple)
    google_web_client_id: str = ""
    godot_bin: str = ""
    game_project: str = str(Path(__file__).resolve().parents[2] / "game")
    verifier_timeout_seconds: int = 90
    job_lease_seconds: int = 240
    max_job_attempts: int = 3
    worker_contract_wait_seconds: int = 7200
    access_ttl_seconds: int = 900
    refresh_ttl_seconds: int = 2592000
    refresh_recovery_seconds: int = 120
    transport_profile: str = "compact"
    max_body_bytes: int = 8 * 1024 * 1024
    rate_limit_per_minute: int = 600
    auth_limit_per_minute: int = 30
    write_limit_per_minute: int = 90
    max_queued_runs: int = 128
    publication_evidence_bytes: int = 64 * 1024 * 1024
    publication_evidence_count: int = 128
    discovery_catalogue_limit: int = 100000
    discovery_snapshot_ids: int = 1000000
    discovery_snapshot_count: int = 2048
    discovery_create_per_minute: int = 20
    worker_stale_seconds: int = 300
    worker_shutdown_grace_seconds: int = 5
    readiness_cache_seconds: int = 2
    readiness_storage_cache_seconds: int = 30
    readiness_timeout_seconds: int = 2
    histogram_refresh_seconds: int = 900
    retention_days: int = 90
    backup_marker_path: str = ""
    database_pool_size: int = 4
    database_pool_overflow: int = 0
    database_pool_timeout_seconds: int = 3
    database_statement_timeout_ms: int = 10000
    upload_concurrency: int = 2
    edge_limit_per_minute: int = 12000
    pre_auth_limit_per_minute: int = 600
    trusted_proxy_networks: tuple[str, ...] = field(default_factory=tuple)
    persistent_verifier: bool = True
    verifier_recycle_jobs: int = 100
    allow_sync_track_validation: bool = False
    local_drafts_only: bool = True
    object_backend: str = "local"
    gcs_bucket: str = ""
    gcs_prefix: str = "bmt/v1"
    s3_endpoint: str = ""
    s3_bucket: str = ""
    s3_region: str = "us-east-1"
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_session_token: str = ""
    s3_prefix: str = "bmt/v1"

    def __post_init__(self):
        from .client_address import proxy_networks
        proxy_networks(self.trusted_proxy_networks)
        if not self.local_drafts_only and self.environment != "test":
            raise ValueError("Legacy remote drafts are available only to explicit compatibility test fixtures")
        if self.client_quality_enabled and not self.telemetry_enabled:
            raise ValueError("Client quality requires bounded product telemetry transport")
        if (not 50 <= self.telemetry_client_backlog <= 1000000
                or not 1 <= self.telemetry_processor_batch <= 1000
                or not 1 <= self.telemetry_raw_days <= 30 or not 14 <= self.telemetry_fact_days <= 366):
            raise ValueError("Invalid bounded telemetry settings")
        for key in (self.admin_owner_key, self.admin_analyst_key):
            if key and len(key) < 32:
                raise ValueError("Admin keys require at least 32 characters")
        if self.admin_owner_key and self.admin_owner_key in (self.admin_analyst_key, self.dev_auth_key):
            raise ValueError("Admin keys must be separate credentials")
        if self.admin_analyst_key and self.admin_analyst_key == self.dev_auth_key:
            raise ValueError("Admin keys must be separate credentials")
        if self.google_web_client_id and self.google_web_client_id not in self.google_client_ids:
            raise ValueError("Google web client ID must also be in BMT_GOOGLE_CLIENT_IDS")
        for name in (
            "histogram_refresh_seconds",
            "verifier_timeout_seconds",
            "job_lease_seconds",
            "max_job_attempts",
            "worker_contract_wait_seconds",
            "access_ttl_seconds",
            "refresh_ttl_seconds",
            "refresh_recovery_seconds",
            "max_body_bytes",
            "rate_limit_per_minute",
            "auth_limit_per_minute",
            "write_limit_per_minute",
            "max_queued_runs",
            "publication_evidence_bytes", "publication_evidence_count", "discovery_catalogue_limit",
            "discovery_snapshot_ids", "discovery_snapshot_count",
            "discovery_create_per_minute",
            "worker_stale_seconds",
            "worker_shutdown_grace_seconds",
            "readiness_cache_seconds", "readiness_storage_cache_seconds", "readiness_timeout_seconds",
            "retention_days",
            "privacy_backup_days", "privacy_purchase_days",
            "database_pool_size", "database_pool_timeout_seconds", "database_statement_timeout_ms",
            "upload_concurrency", "edge_limit_per_minute", "pre_auth_limit_per_minute", "verifier_recycle_jobs",
        ):
            value = getattr(self, name)
            if type(value) is not int or value <= 0:
                raise ValueError(f"BMT_{name.upper()} must be a positive integer")
        if self.database_pool_overflow < 0 or self.upload_concurrency > 8:
            raise ValueError("Invalid pool overflow or upload concurrency")
        if self.refresh_recovery_seconds > 300 or self.transport_profile not in ("legacy", "compact"):
            raise ValueError("Invalid recovery window or transport profile")
        if self.readiness_cache_seconds > 5 or self.readiness_storage_cache_seconds > 60 or self.readiness_timeout_seconds > 5:
            raise ValueError("Readiness cache/deadline exceeds the bounded probe allowance")
        if self.max_body_bytes > 8 * 1024 * 1024:
            raise ValueError("BMT_MAX_BODY_BYTES cannot exceed the 8 MiB storage/verifier limit")
        # A cold worker can run an engine version probe (10s), manifest process
        # and replay process, followed by database finalization (15s bound).
        if self.job_lease_seconds <= 2 * self.verifier_timeout_seconds + 25:
            raise ValueError("Job lease must exceed twice the verifier timeout plus 25 seconds")
        if self.environment not in ("production", "development", "test"):
            raise ValueError("Invalid BMT_ENVIRONMENT")
        if self.object_backend not in ("local", "s3", "gcs"):
            raise ValueError("Invalid object backend")
        if self.object_backend == "gcs":
            import re
            if not re.fullmatch(r"[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]", self.gcs_bucket):
                raise ValueError("GCS requires an explicit bucket name")
            if (not re.fullmatch(r"[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*", self.gcs_prefix)
                    or len(self.gcs_prefix) > 256):
                raise ValueError("Invalid GCS object prefix")
        if self.object_backend == "s3":
            from urllib.parse import urlsplit
            parsed = urlsplit(self.s3_endpoint)
            if (not all((self.s3_bucket,self.s3_access_key,self.s3_secret_key,self.s3_region))
                    or parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.query or parsed.fragment):
                raise ValueError("S3 needs explicit HTTPS endpoint, bucket, region and private credentials")
        if self.allow_sync_track_validation and self.environment == "production":
            raise ValueError("Synchronous track validation is restricted to explicit development/test configuration")
        if self.dev_auth_enabled and (self.environment != "development" or len(self.dev_auth_key) < 32):
            raise ValueError(
                "Development auth requires development environment and a secret of at least 32 characters"
            )
        if self.test_drivers_enabled and (self.environment != "development" or not self.dev_auth_enabled):
            raise ValueError("Test drivers require explicitly enabled development authentication")
        if self.purchase_simulation_enabled and (self.environment != "development" or not self.dev_auth_enabled):
            raise ValueError("Purchase simulation requires explicitly enabled development authentication")

    @classmethod
    def from_env(cls):
        defaults = cls()
        values = {}
        for name in cls.__dataclass_fields__:
            raw = os.environ.get("BMT_" + name.upper())
            if raw is None:
                continue
            default = getattr(defaults, name)
            if name in ("google_client_ids", "android_app_link_certificates", "trusted_proxy_networks"):
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

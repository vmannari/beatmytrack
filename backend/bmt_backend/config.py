import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    admin_owner_key: str = ""
    admin_analyst_key: str = ""
    studio_legacy_keys_enabled: bool = False
    workload_role: str = "api"
    studio_staff_audiences: tuple[str, ...] = field(default_factory=tuple)
    studio_staff_subjects: str = ""
    studio_staff_require_mfa: bool = True
    studio_identity_project: str = ""
    studio_identity_tenant: str = ""
    studio_identity_api_key: str = ""
    studio_identity_auth_domain: str = ""
    studio_identity_login_hint: str = ""
    studio_business_cohorts: bool = False
    studio_analysis_database_url: str = ""
    studio_analysis_mode: str = "replica"
    studio_analysis_statement_timeout_ms: int = 5000
    studio_monitor_source_tokens: str = ""
    studio_monitor_external_notifiers: tuple[str, ...] = ()
    studio_monitor_webhook_url: str = ""
    studio_monitor_webhook_key: str = ""
    studio_monitor_poll_seconds: int = 30
    studio_play_package: str = ""
    studio_admob_account: str = ""
    studio_usage_project: str = ""
    studio_usage_region: str = "europe-west1"
    studio_usage_resources: str = ""
    studio_usage_player_id: str = ""
    studio_usage_billing_table: str = ""
    studio_usage_billing_location: str = "EU"
    environment: str = "production"
    dev_auth_enabled: bool = False
    test_drivers_enabled: bool = False
    test_driver_api_url: str = ""
    purchase_simulation_enabled: bool = False
    temporary_ad_resumes_enabled: bool = False
    telemetry_enabled: bool = False
    client_quality_enabled: bool = False
    privacy_developer_name: str = "Ville Mannari"
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
    run_wait_capacity: int = 4
    publication_evidence_bytes: int = 64 * 1024 * 1024
    publication_evidence_count: int = 128
    discovery_create_per_minute: int = 20
    discovery_work_units_per_minute: int = 600
    discovery_expensive_units_per_minute: int = 240
    discovery_network_reads_per_minute: int = 1200
    discovery_network_burst: int = 120
    discovery_network_creates_per_minute: int = 40
    discovery_network_rows_per_minute: int = 202000
    discovery_actor_member_rows: int = 202000
    discovery_actor_member_bytes: int = 64 * 1024 * 1024
    discovery_storage_member_rows: int = 16000000
    discovery_storage_member_bytes: int = 4 * 1024 * 1024 * 1024
    worker_stale_seconds: int = 300
    worker_shutdown_grace_seconds: int = 5
    readiness_cache_seconds: int = 2
    readiness_storage_cache_seconds: int = 30
    readiness_timeout_seconds: int = 2
    histogram_refresh_seconds: int = 900
    # Zero leaves launch unannounced. Enable only for a declared future UTC Monday.
    world_ranking_launch_week: int = 0
    world_ranking_batch_size: int = 2000
    world_ranking_statement_ms: int = 30000
    world_ranking_pause_ms: int = 25
    world_ranking_max_queue_age_seconds: int = 30
    retention_days: int = 90
    backup_marker_path: str = ""
    database_pool_size: int = 4
    database_pool_overflow: int = 0
    database_pool_timeout_seconds: int = 3
    database_statement_timeout_ms: int = 10000
    upload_concurrency: int = 2
    telemetry_http_concurrency: int = 4
    edge_limit_per_minute: int = 12000
    pre_auth_limit_per_minute: int = 600
    trusted_proxy_networks: tuple[str, ...] = field(default_factory=tuple)
    persistent_verifier: bool = True
    verifier_recycle_jobs: int = 100
    verifier_idle_seconds: int = 30
    allow_sync_track_validation: bool = False
    local_drafts_only: bool = True
    object_backend: str = "local"
    object_packing_enabled: bool = False
    object_pack_records: int = 128
    object_pack_bytes: int = 6 * 1024 * 1024
    object_pending_bytes_per_partition: int = 64 * 1024 * 1024
    object_pending_records_per_partition: int = 8192
    object_pack_flush_seconds: int = 5
    http_success_sample_per_mille: int = 10
    http_metrics_interval_seconds: int = 60
    cost_archive_days: int = 7
    cost_archive_batch: int = 500
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
        if type(self.verifier_idle_seconds) is not int or not 0 <= self.verifier_idle_seconds <= 300:
            raise ValueError("Verifier idle retirement must be between zero and 300 seconds")
        if (not 1 <= self.object_pack_records <= 128 or not 65536 <= self.object_pack_bytes <= 8*1024*1024
                or not self.object_pack_bytes <= self.object_pending_bytes_per_partition <= 128*1024*1024
                or not 1 <= self.object_pending_records_per_partition <= 16384
                or not 1 <= self.object_pack_flush_seconds <= 30):
            raise ValueError("Invalid bounded object packing policy")
        if not 0 <= self.http_success_sample_per_mille <= 1000 or not 1 <= self.http_metrics_interval_seconds <= 300:
            raise ValueError("Invalid bounded HTTP observability policy")
        if not 7 <= self.cost_archive_days <= 90 or not 1 <= self.cost_archive_batch <= 1000:
            raise ValueError("Invalid exact cost-archive policy")
        if self.workload_role not in ("api", "admin", "worker", "migrator", "operator"):
            raise ValueError("Invalid workload role")
        if self.environment == "production":
            if self.studio_legacy_keys_enabled or self.admin_owner_key or self.admin_analyst_key:
                raise ValueError("Production Studio requires named staff credentials; legacy administrator keys are forbidden")
            if not self.studio_staff_require_mfa:
                raise ValueError("Production Studio requires verified MFA")
            if self.temporary_ad_resumes_enabled:
                raise ValueError("Temporary ad-preview resumes are restricted to development/test")
        if self.workload_role == "worker" and (self.admin_owner_key or self.admin_analyst_key
                or self.studio_staff_subjects or self.studio_monitor_source_tokens
                or self.studio_monitor_webhook_key or self.studio_monitor_webhook_url):
            raise ValueError("Workers cannot receive administrator or monitor credentials")
        if (type(self.world_ranking_launch_week) is not int or self.world_ranking_launch_week < 0
                or (self.world_ranking_launch_week and (self.world_ranking_launch_week-345600) % 604800)):
            raise ValueError("World Ranking launch must be a Monday at 00:00 UTC")
        if not 1 <= self.world_ranking_batch_size <= 10000:
            raise ValueError("World Ranking batch must contain 1 to 10000 players")
        if not 1000 <= self.world_ranking_statement_ms <= 60000 or not 10 <= self.world_ranking_pause_ms <= 1000:
            raise ValueError("World Ranking requires bounded statements and a cooperative pause")
        if not 5 <= self.world_ranking_max_queue_age_seconds <= 300:
            raise ValueError("World Ranking must yield to delayed foreground verification")
        from .studio_settings import validate_studio_settings
        validate_studio_settings(self)
        from .client_address import proxy_networks
        proxy_networks(self.trusted_proxy_networks)
        if not self.local_drafts_only and self.environment != "test":
            raise ValueError("Legacy remote drafts are available only to explicit compatibility test fixtures")
        if self.client_quality_enabled and not self.telemetry_enabled:
            raise ValueError("Client quality requires bounded product telemetry transport")
        if (self.studio_analysis_database_url
                and not self.studio_analysis_database_url.startswith("postgresql+psycopg://")):
            raise ValueError("Studio analysis requires a dedicated PostgreSQL read replica")
        if (type(self.studio_analysis_statement_timeout_ms) is not int
                or not 100 <= self.studio_analysis_statement_timeout_ms <= 30000):
            raise ValueError("Studio analysis timeout must be between 100 and 30000 milliseconds")
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
            "run_wait_capacity",
            "publication_evidence_bytes", "publication_evidence_count",
            "discovery_create_per_minute",
            "discovery_work_units_per_minute", "discovery_expensive_units_per_minute",
            "discovery_network_reads_per_minute", "discovery_network_burst",
            "discovery_network_creates_per_minute", "discovery_network_rows_per_minute",
            "discovery_actor_member_rows", "discovery_actor_member_bytes",
            "discovery_storage_member_rows", "discovery_storage_member_bytes",
            "worker_stale_seconds",
            "worker_shutdown_grace_seconds",
            "readiness_cache_seconds", "readiness_storage_cache_seconds", "readiness_timeout_seconds",
            "retention_days",
            "privacy_backup_days", "privacy_purchase_days",
            "database_pool_size", "database_pool_timeout_seconds", "database_statement_timeout_ms",
            "upload_concurrency", "telemetry_http_concurrency", "edge_limit_per_minute", "pre_auth_limit_per_minute", "verifier_recycle_jobs",
        ):
            value = getattr(self, name)
            if type(value) is not int or value <= 0:
                raise ValueError(f"BMT_{name.upper()} must be a positive integer")
        if self.database_pool_overflow < 0 or self.upload_concurrency > 8:
            raise ValueError("Invalid pool overflow or upload concurrency")
        if min(self.discovery_work_units_per_minute, self.discovery_expensive_units_per_minute) < 60:
            raise ValueError("Discovery work budgets must reserve at least one 1.5s query allowance")
        if self.telemetry_http_concurrency > 16:
            raise ValueError("Telemetry HTTP concurrency cannot exceed 16 bounded request trees")
        if self.run_wait_capacity > 64:
            raise ValueError("Run wait capacity must leave room for ordinary HTTP requests")
        if self.refresh_recovery_seconds > 300 or self.transport_profile != "compact":
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
            if name in ("google_client_ids", "android_app_link_certificates", "trusted_proxy_networks", "studio_staff_audiences", "studio_monitor_external_notifiers"):
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

"""Prepare a reviewable Google-only optimisation profile; never call cloud APIs."""
import argparse
import json
from pathlib import Path


def profile(service_name):
    if not service_name or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789-" for c in service_name):
        raise ValueError("Supply the explicit owned API service name")
    return {
        "schema": "bmt-google-cost-profile-v1",
        "enable_after": ["migrations0065/0066 and explicit workload grants", "compatible API, packing supervisor and client",
                         "archive/pack backup restore rehearsal", "PostgreSQL concurrency and capacity calibration"],
        "staging_configuration_overlay": {"cost_optimisation": True, "api_instance_billing": False},
        "api_instance_billing": "Keep request billing at quiet traffic; compare measured sustained traffic before enabling",
        "logging_exclusion": {"name": "bmt-sampled-success-requests", "disabled": False,
            "filter": 'resource.type="cloud_run_revision" AND resource.labels.service_name="'+service_name
                +'" AND log_id("run.googleapis.com/requests") AND httpRequest.status>=200 AND httpRequest.status<400 AND NOT sample(insertId,0.01)'},
        "preserve_logs": ["all application HTTP aggregates", "errors and slow application requests", "financial and security audit evidence"],
        "storage": {"same_region": True, "mixed_content_blanket_age_delete": False,
            "cleanup": "Reference/pin-aware candidate GC, pack compaction and delayed retirement",
            "soft_delete_and_versioning": "Inspect actual retained copies and backup protection before changing provider policy"},
        "commitments": "No purchases until a sustained measured baseline exists",
        "development_resources": "Retain active work; use ownership/expiry labels and current retain-data guards for eventual cleanup",
        "spot_capacity": "Optional separate workers for checkpointed offline rebuilds only; not intake, database or timely result acceptance",
        "certification": "Local implementation profile, not demonstrated one-million-DAU capacity or a bill ceiling",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-service", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(profile(args.api_service), indent=2)+"\n", encoding="utf-8")
    print("Prepared profile; no cloud calls or changes")


if __name__ == "__main__":
    main()

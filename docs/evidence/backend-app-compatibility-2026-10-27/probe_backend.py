"""Diagnostic characterization, not the intended future compatibility policy.

Uses production ticket/eligibility/worker predicates with synthetic published
tracks in the existing disposable domain fixture. Never connects to production.
Run after the native client probe so the matrix uses actual seven-car hashes.
"""
from copy import deepcopy
import json
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import select

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "backend" / "tests"))
from test_domains import FakeVerifier, domain, headers  # noqa: E402,F401
from test_rivalry import seed  # noqa: E402

from bmt_backend.catalog_builds import check_catalog  # noqa: E402
from bmt_backend.challenges import compatible  # noqa: E402
from bmt_backend.contracts import build_contract, current_manifest  # noqa: E402
from bmt_backend.job_contracts import capability_matches, pinned_filter, worker_filter  # noqa: E402
from bmt_backend.operations import competition_health, heartbeat  # noqa: E402
from bmt_backend.rivalry import eligible_query  # noqa: E402
from bmt_backend.rivalry_planning import plan_contract  # noqa: E402
from bmt_backend.runs import board_manifest  # noqa: E402
from bmt_backend.track_models import Board, OperationState, TrackVersion  # noqa: E402

OUTPUT = Path(__file__).parent


class AuditVerifier(FakeVerifier):
    def __init__(self, manifest):
        self.build = deepcopy(manifest)

    def manifest(self):
        return deepcopy(self.build)


def test_current_compatibility_matrix(domain):
    assert not domain.postgres, "Run this offline diagnostic with -k sqlite"
    baseline = json.loads((OUTPUT / "client.json").read_text())["manifest"]
    verifier = AuditVerifier(baseline)
    domain.app.state.verifier = verifier
    version_id = seed(domain, 1)[0]
    heartbeat(domain.app, "baseline-worker", build=build_contract(baseline))
    with domain.factory() as db:
        pinned = board_manifest(db.get(TrackVersion, version_id), "compact")
    cases = [
        ("identical", {}, True, True),
        ("informational_app_build", {"client_build":"different-art-and-ui-build"}, True, True),
        ("extra_top_level_metadata", {"future_optional_field":"ignored"}, True, True),
        ("maximum_frame_metadata", {"max_frames":baseline["max_frames"] - 1}, True, True),
    ]
    for field in ("engine_version", "verifier_version", "physics_version", "rules_key",
                  "compiler_version", "track_schema", "replay_schema"):
        cases.append((field, {field:baseline[field] + "-different"}, False, False))
    cases.extend([
        ("tick_rate", {"tick_rate":60}, False, False),
        ("laps", {"laps":3}, False, False),
    ])
    for name, car, changes, ticket_ok, eligible in [
        ("unrelated_electric_tune", "electric", {"handling_version":"electric-next", "config_hash":"changed"}, True, True),
        ("selected_car_tune", "compact", {"config_hash":"changed"}, False, False),
        ("selected_handling_label", "compact", {"handling_version":"handling-next"}, False, False),
        ("selected_car_optional_metadata", "compact", {"future_optional_field":"ignored"}, True, True),
    ]:
        vehicles = deepcopy(baseline["vehicles"])
        vehicles[car].update(changes)
        cases.append((name, {"vehicles":vehicles}, ticket_ok, eligible))
    vehicles = deepcopy(baseline["vehicles"])
    vehicles["future-car"] = {"handling_version":"future-1", "config_hash":"future"}
    cases.append(("added_unrelated_car", {"vehicles":vehicles}, True, True))
    vehicles = deepcopy(baseline["vehicles"])
    del vehicles["electric"]
    cases.append(("removed_unrelated_car", {"vehicles":vehicles}, True, True))
    rows = []
    for name, changes, ticket_ok, eligible in cases:
        active = {**deepcopy(baseline), **changes}
        verifier.build = active
        response = domain.client.post("/v1/run-tickets", json={"version_id":version_id,"vehicle_id":"compact"},
                                      headers=headers(domain, "Alice"))
        assert response.status_code == (201 if ticket_ok else 409), (name, response.text)
        if name == "identical":
            board_id = response.json()["board_id"]
        try:
            compatible(SimpleNamespace(app=domain.app), pinned)
            challenge_ok = True
        except HTTPException as exc:
            assert exc.status_code == 409
            challenge_ok = False
        with domain.factory() as db:
            candidate_ids = [v.id for v in db.scalars(eligible_query(active,"compact"))]
            assert (version_id in candidate_ids) == eligible, name
            if response.status_code == 201:
                stored_board = db.get(Board, response.json()["board_id"])
                assert stored_board.manifest == pinned, "Unrelated updates must not rewrite an existing board"
            try:
                check_catalog(db, active)
                catalogue_ok = True
            except RuntimeError:
                catalogue_ok = False
            baseline_worker_matches = bool(db.scalar(select(OperationState.id).where(
                OperationState.id == "worker:baseline-worker", worker_filter(OperationState.details["build"],pinned))))
            # Run actual SQL worker predicates against the same pinned manifest.
            queue_matches = bool(db.scalar(select(Board.id).where(Board.id == board_id,pinned_filter(Board.manifest,active))))
        health = competition_health(domain.app)
        capability = capability_matches(pinned, active)
        assert capability == queue_matches, name
        assert baseline_worker_matches, "The original worker still supports the immutable original job"
        rows.append({"case":name,"compact_ticket_http":response.status_code,
            "ticket_error":response.json().get("detail","") if response.status_code != 201 else "",
            "compact_rivalry_eligible":version_id in candidate_ids,"existing_challenge_compatible":challenge_ok,
            "current_worker_can_claim_original_job":queue_matches,"baseline_worker_still_supports_original_job":baseline_worker_matches,
            "whole_catalogue_check":catalogue_ok,"old_worker_considered_available":health["available_workers"],
            "health_status":health["status"],"compact_weekly_contract_changed":plan_contract(active,"compact") != plan_contract(baseline,"compact")})
    verifier.build = baseline
    # Actual latest EV update: the six other config entries are identical, but
    # the .74 -> .75 label must no longer block the six unchanged cars.
    historical_path = ROOT / "docs/evidence/electric-slide-access-2026-10-27/before/backend__tests__fixtures__verified_oval.json"
    old = current_manifest(json.loads(historical_path.read_text())["expected_manifest"])
    assert old["physics_version"] == "arcade-planar-0.74"
    assert [car for car in baseline["vehicles"] if old["vehicles"][car] != baseline["vehicles"][car]] == ["electric"]
    shared_changed = [field for field in build_contract(baseline)
                      if field != "vehicles" and baseline[field] != old[field]]
    assert shared_changed == ["physics_version"]
    with domain.factory() as db:
        version = db.get(TrackVersion,version_id)
        original_manifest = deepcopy(version.manifest)
        version.manifest = {**version.manifest,**build_contract(old)}
        db.commit()
    blast_radius = []
    for car in baseline["vehicles"]:
        response = domain.client.post("/v1/run-tickets",json={"version_id":version_id,"vehicle_id":car},headers=headers(domain,"Alice"))
        assert response.status_code == (409 if car == "electric" else 201)
        blast_radius.append({"vehicle":car,"unchanged_handling":old["vehicles"][car] == baseline["vehicles"][car],"http":response.status_code})
    with domain.factory() as db:
        db.get(TrackVersion,version_id).manifest = original_manifest
        db.commit()
    report = {"matrix_cases":len(rows),"matrix":rows,"ev_update_blast_radius":blast_radius,
        "historical_manifest_source":str(historical_path.relative_to(ROOT)),
        "historical_shared_fields_changed":shared_changed,
        "unchanged_cars_blocked":sum(row["unchanged_handling"] and row["http"] == 409 for row in blast_radius),
        "scope":"Production HTTP ticket gate and SQL predicates, synthetic SQLite rows and verifier metadata; no actual historical physics execution or live services"}
    (OUTPUT / "backend.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(f"COMPATIBILITY_BACKEND_AUDIT: {len(rows)} scenarios, {len(blast_radius)} car tickets, no live traffic")

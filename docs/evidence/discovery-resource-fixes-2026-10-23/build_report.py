"""Build reviewable evidence from retained local receipts and scoped source files."""
import difflib
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FOLDER = Path(__file__).parent
BASELINE = json.loads((FOLDER / "baseline.json").read_text())
ADDED = [
    "backend/bmt_backend/discovery_guard.py",
    "backend/bmt_backend/discovery_retention.py",
    "backend/bmt_backend/migrations/versions/0057_discovery_resource_guards.py",
    "backend/tests/test_discovery_resources.py",
]
NOTE = (
    "2026-10-23 REX01-REX04/R01/Q01: Discovery account fences fail promptly under contention; "
    "shared actor work credits, cross-replica expensive-operation leases and escalating timeout cooldowns "
    "cover cursors, Random and non-text filters while preserving ordinary-page capacity. Captured-ID "
    "filtering and transactional actor/sixteen-stripe storage caps bound personal copies; migration0057 "
    "preserves legacy members through bounded backfill, expiry and erasure. Anonymous IPv6 /64 budgets, "
    "bursts and two-per-network/four-per-process receivers retain exact cursor scope and independent "
    "signed-in players. Broad SQLite57pass/2skip, earlier PostgreSQL55pass/1skip, final resource "
    "SQLite21pass/3skip/PostgreSQL20pass/1skip, receiver3SQLite/2PostgreSQL and security106 pass; "
    "Ruff and real Uvicorn/h11 framing pass. Local pool4 probe rejects three busy-account requests "
    "in25.13ms with only the holder connection occupied; another player reads in8.62ms. Local5001-track "
    "warm-page median47.19ms is not cloud/DAU certification. Commands, corrections, fingerprints and "
    "rollout limits: docs/evidence/discovery-resource-fixes-2026-10-23/report.json. Coordinated0057/API/worker "
    "release, old-writer drain, representative migration/load and capacity tuning remain; no live "
    "migration/account mutation/deployment, phone attachment check/device test or APK action. "
    "Concurrent work is preserved."
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def notes():
    for name, prefix in (
        ("AGENTS.md", "## Discovery resource-exhaustion fixes override (2026-10-23)\n"),
        ("DEVELOPMENT_STATUS.md", ""),
    ):
        target = ROOT / name
        before = target.read_bytes()
        if b"REX01-REX04" in before:
            continue
        content = (prefix + NOTE + "\n\n").encode() + before
        if target.read_bytes() != before:
            raise RuntimeError("Concurrent documentation update: " + name)
        target.write_bytes(content)


def main():
    if "--notes" in sys.argv:
        notes()
    checkpoint, patches = {}, []
    for name in [*BASELINE, *ADDED]:
        data = (ROOT / name).read_bytes()
        before = FOLDER / "before" / name.replace("/", "__")
        original = before.read_bytes() if before.exists() else b""
        if before.exists() and digest(original) != BASELINE[name]:
            raise RuntimeError("Baseline snapshot changed: " + name)
        checkpoint[name] = {"baseline_sha256": BASELINE.get(name), "final_sha256": digest(data),
                            "bytes": len(data)}
        patches.extend(difflib.unified_diff(original.decode("utf-8-sig").splitlines(keepends=True),
            data.decode("utf-8-sig").splitlines(keepends=True), fromfile="baseline/"+name,
            tofile="final/"+name))
    (FOLDER / "source-checkpoint.json").write_text(json.dumps({
        "scope": "Task source checkpoint, not a commit or complete release artifact. Shared-file differences "
                 "may also include concurrent authorized work; preserve that work when integrating.",
        "files": checkpoint}, indent=2)+"\n", encoding="utf-8")
    (FOLDER / "baseline-to-final.patch").write_text("".join(patches), encoding="utf-8")
    receipts = []
    for path in sorted(FOLDER.rglob("*.xml")):
        suites = list(ET.parse(path).getroot().iter("testsuite"))
        counts = {key: sum(int(s.get(key, "0")) for s in suites)
                  for key in ("tests", "failures", "errors", "skipped")}
        counts["passed"] = counts["tests"]-counts["failures"]-counts["errors"]-counts["skipped"]
        receipts.append({"receipt": path.relative_to(FOLDER).as_posix(), **counts})
    profile = json.loads((FOLDER / "profile-result.json").read_text())
    framing = json.loads((FOLDER / "framing-result.json").read_text())
    report = {
        "date": "2026-10-23", "generated_at": datetime.now(timezone.utc).isoformat(),
        "scope": "Implement the two immediate discovery resource-exhaustion fixes and both smaller "
                 "retention/network follow-ups, integrated with ongoing high-priority hardening. Local only.",
        "review": "../discovery-resource-exhaustion-2026-10-23/report.json",
        "requirements": [
            {"id": "REX01/RE01", "status": "implemented",
             "change": "Discovery-only NOWAIT account privacy fences at authentication and every commit. "
                       "Contended requests return503/Retry-After1 without joining owner-row lock queues; "
                       "revocation/removal remain authoritative. Shared small/bulk query slots are capped "
                       "at max(1,min(3,pool_size-1)); this reserves other gameplay capacity when pool_size>1.",
             "checks": ["PostgreSQL held-owner test and profile", "account removal/lease commit regression",
                        "106 security/privacy/communication/staging checks"]},
            {"id": "REX02/RE02", "status": "implemented",
             "change": "Separate durable ordinary/expensive work credits, independent of view creation. "
                       "Random, text/non-text filters, personal state and authenticated initializations "
                       "use the expensive lane. One ten-second expensive lease per actor across replicas; "
                       "fenced tokens cannot commit/refund/release replacement work. Actual query/Random/visibility "
                       "budget failures trigger shared2/4/8/16/30s cooldown, preserving cheap browsing. "
                       "Older replica windows cannot reset newer credit windows. Request connections are "
                       "released before refund metadata transactions.",
             "checks": ["two API instances share cooldown and duplicate admission", "cursor/filter/Random retry coverage",
                        "non-text gate", "replaced lease", "clock rollback", "light-lane independence",
                        "SQLite deadline and busy-timeout pool lifecycle"]},
            {"id": "REX03/RE03", "status": "implemented",
             "change": "Bounded captured-epoch indexed batches discard nonexistent favorite/history IDs; "
                       "unused history is not copied. Device-local lists remain untouched. Outstanding actor "
                       "and sixteen service-stripe member/charged-byte caps include expired physical rows. "
                       "Counters, insertion, expiry and erasure commit/rollback atomically. Legacy members "
                       "remain intact during512-member indexed backfill; accounting compares cursor tuples "
                       "with database collation, including Unicode. New member writes wait503 until ready.",
             "checks": ["nonexistent IDs persist zero rows", "typed real IDs", "actor rows/bytes and service stripes",
                        "rollback", "expiry", "erasure", "partial legacy backfill/rollback",
                        "0056 downgrade/legacy seed/0057 upgrade on SQLite and PostgreSQL"]},
            {"id": "REX04/RE04", "status": "implemented",
             "change": "Secondary shared anonymous IPv6/64 or IPv4/32 read/burst/create/member budgets. "
                       "Small anonymous reception is additionally capped at two/network and four/process. "
                       "Trusted proxy resolution and exact peer cursor identity are retained. Validated "
                       "signed-in players keep separate account budgets and receiver capacity.",
             "checks": ["rotating actual IPv6 peers", "exact cursor scope", "shared-network signed-in independence",
                        "untrusted forwarding headers/invalid credentials", "same-prefix and distinct-prefix receivers",
                        "receiver cleanup", "real TCP/Uvicorn/h11 framing"]},
        ],
        "default_policy": {
            "work_credit_unit_ms": 25, "reservation_units": 60,
            "ordinary_min_charge": 1, "expensive_min_charge": 4,
            "ordinary_units_per_minute": 600, "expensive_units_per_minute": 240,
            "expensive_lease_seconds": 10, "idle_guard_retention_seconds": 180,
            "network_requests_per_minute": 1200, "network_requests_per_ten_second_bucket": 120,
            "network_creations_per_minute": 40, "network_inserted_members_per_minute": 202000,
            "actor_outstanding_members": 202000, "actor_charged_bytes": 64*1024*1024,
            "service_storage_stripes": 16, "service_outstanding_members": 16000000,
            "service_charged_bytes": 4*1024*1024*1024,
            "charge_definition": "128+UTF8 kind/identifier lengths per row, not physical PostgreSQL heap/index/WAL bytes",
            "caveats": "A service stripe may fill before aggregate capacity. Tune against real demand, NAT behavior, "
                       "database allocation and cleanup capacity. Conservative lost refunds never increase allowance.",
        },
        "validation": {"test_receipts": receipts, "overlap": "Runs overlap; do not sum counts as unique tests.",
            "ruff": "All checks passed for14 scoped source/migration/test files after final runtime edits.",
            "whitespace": "Scoped git diff --check passed; source checkpoint also checks new text files.",
            "warnings": "Existing Starlette/httpx deprecation and SQLite expression-index reflection warnings retained.",
            "owned_postgres": "Fresh labelled loopback PostgreSQL17 containers only; ownership verified before cleanup. "
                              "Every created container was removed; no live settings used."},
        "local_profile": profile, "real_http": framing,
        "comparisons": [
            "Review probe: held owner plus three waiters occupied all four pool connections and delayed another player. "
            "Final probe: three503 rejections in25.13ms leave only the holder connection checked out; "
            "another-player read succeeds in8.62ms while the lock remains held. Controlled local behavior, not throughput certification.",
            "Review: eight ignored-Retry-After attempts re-entered the injected timeout stage. Final: one injected "
            "timeout-stage entry and five cooldown denials, with ordinary browsing200. Instrumented stage proves admission, not CPU cost.",
        ],
        "optional_review_optimization": {
            "id": "RE05",
            "disposition": "Shared work-credit admission now bounds repeated creation-quota denials, including "
                           "cached-query retries. Exhausted work credit is rejected before freshness lookup. "
                           "While credit remains, creation denials may still perform one bounded freshness statement. "
                           "No blanket negative-cache hint bypasses existing-view reuse or current readiness/account checks. "
                           "This residual bounded metadata cost is not an unbounded catalogue scan.",
        },
        "corrected_attempts": [
            "initial.log: first launch lacked PYTHONPATH; used workspace backend path and the secure virtualenv thereafter.",
            "first.xml:34pass/3fail/1skip. Updated the old Retry-After1 assertion to the deliberate initial cooldown2; "
            "limited cooldowns to actual query/Random/visibility budget failures so preparing/stale-index semantics remain; "
            "the concurrent small/bulk admission fixture passed on final integration without weakening its assertion.",
            "resources-first.xml:14pass/1fail/1skip. Burst fixture crossed a ten-second window; froze its clock and retained exact boundary behavior.",
            "history/http-powershell-redirection.log: probe printed all expected results but PowerShell classified stderr "
            "logging as a native-command error. Re-ran with captured subprocess streams; explicit framing/pool/source assertions pass, exit0.",
            "Documentation patch initially failed context matching on a concurrent status paragraph; no file changed. "
            "Final note prepends preserve all current content.",
        ],
        "remaining_acceptance": [
            "Coordinated0057 plus matching API/worker release; drain old collection writers/cleanup workers. "
            "Back up first, measure metadata index build/lock time on representative data, and verify storage_backfill_ready/stripe totals.",
            "New personal-copy writes deliberately wait during legacy accounting; ordinary feeds and existing views stay readable. "
            "Existing storage above new caps is accounted without destructive truncation; new intake fails closed until capacity drains.",
            "Measure production-like filter mix, migration volume, pool/CPU/memory, latency tails, storage/WAL and NAT false positives. "
            "The5001-track profile is synthetic TestClient/PostgreSQL, not network/cloud/million-DAU or500-million-account certification.",
            "No upstream WAF/volumetric-DDoS configuration changed; application safeguards are not an upstream traffic-capacity claim.",
        ],
        "reproduction": [
            "Set PYTHONPATH to the absolute workspace backend directory; use .tools/backend-secure-venv/Scripts/python.exe.",
            "python -m pytest backend/tests/test_discovery_v3.py backend/tests/test_discovery_projection.py "
            "backend/tests/test_discovery_hardening.py backend/tests/test_discovery_resources.py -q -k sqlite",
            "python docs/evidence/discovery-resource-fixes-2026-10-23/postgres_lab.py "
            "(default broad suites; --resources-only core; --receiver-only final receiver cases; WSL sandbox escalation used)",
            "python docs/evidence/discovery-resource-fixes-2026-10-23/http_probe.py",
            "python -m pytest backend/tests/test_attack_resistance.py backend/tests/test_communication_boundary.py "
            "backend/tests/test_privacy.py backend/tests/test_community_safety.py backend/tests/test_gcp_staging.py -q -k 'not postgres'",
        ],
        "source_checkpoint": "source-checkpoint.json",
        "patch": "baseline-to-final.patch (scoped snapshot difference; shared-file concurrent edits are not exclusively attributed to this task)",
        "not_performed": ["live migration/deployment", "live account/race/publication/queue mutation",
                          "phone attachment check/device test", "APK/export/install", "upstream WAF change"],
    }
    for name in [*BASELINE, *ADDED]:
        for number, line in enumerate((ROOT/name).read_text(encoding="utf-8-sig").splitlines(), 1):
            if line.rstrip() != line:
                raise RuntimeError(f"Trailing whitespace: {name}:{number}")
    (FOLDER / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print("Report, scoped checkpoint and snapshot difference written; trailing-whitespace check passed.")


if __name__ == "__main__":
    main()

"""Add only the completed cost slice to shared documentation."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NOTE = ("2026-10-24 DCOI01-DCOI10/R01/Q01: Persistent exact recording reuse, lossless packed ghosts, reusable discovery previews, "
        "27 bundled official documents, shared GET/immutable preparation and slower-PB write avoidance reduce repeated work. "
        "Explicit cost profile adds durable bounded object packs, encrypted exact retry/reward archives, anonymous exact finance totals, "
        "indexed/pinned retirement, pack-aware backups and low-priority one-connection maintenance. Unsampled compressed-body totals retain "
        "1% fast-success log detail. Backend155pass/18skip, supplemental archive/deployment17, native downloads125 plus eight existing suites "
        "and real HTTP8 pass; actual WSL six-role priority/signal/reaping probe passes. Fixture compressed ghost bytes63487to47400 (25.34%), "
        "not player-day or bill savings. Initial fixture/sandbox corrections and existing0054 downgrade failure remain documented. "
        "Commands, hashes and scoped Git-checked checkpoint: docs/COST_OPTIMISATION_IMPLEMENTATION_2026_10_24.md and "
        "docs/evidence/cost-optimisation-implementation-2026-10-24/report.json. Matching0065/0066 grants/readers/API/worker/client, restore "
        "and PostgreSQL calibration remain; configured local PostgreSQL unavailable. No million-DAU/95%-bill certification, phone/tablet "
        "attachment check or physical-device test, APK, live mutation, purchase or deployment. Concurrent work and owner processes preserved.")


def change(name, edit):
    path = ROOT / name
    data = path.read_bytes()
    if b"DCOI01-DCOI10" in data or (name.endswith("README.md") and b"COST_OPTIMISATION_IMPLEMENTATION_2026_10_24.md" in data):
        return
    before = HERE / "checkpoint-before" / name
    before.parent.mkdir(parents=True, exist_ok=True)
    before.write_bytes(data)
    path.write_bytes(edit(data))


change("AGENTS.md", lambda data: ("## Backend download and operating cost implementation (2026-10-24)\n"+NOTE+"\n\n").encode()+data)
change("DEVELOPMENT_STATUS.md", lambda data: (NOTE+"\n\n").encode()+data)
change("backend/deploy/README.md", lambda data: data.replace(b"\n", b"\n\n2026-10-24 cost optimisation: [implementation and rollout gates](../../docs/COST_OPTIMISATION_IMPLEMENTATION_2026_10_24.md) cover explicit packing/archival enablement, matching0065/0066 migrations and workload grants, compatible readers/supervisor, pack-aware restore and PostgreSQL calibration. The offline Google profile proposes billing/log choices without applying provider changes.\n", 1))
change("docs/README.md", lambda data: data.replace(b"| Run, build and checks |", b"| Backend downloads and costs | [Implementation, validation and rollout gates](COST_OPTIMISATION_IMPLEMENTATION_2026_10_24.md) | [Google-only scenarios](GOOGLE_ONLY_COST_OPTIONS_2026_10_24.md), [cost profile](../backend/deploy/gcp/cost_profile.py) |\n| Run, build and checks |", 1))

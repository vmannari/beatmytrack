"""Add this task's journal block while preserving all other current content."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MARKER = "LOADING-HALF-20261106"
BODY = """## Loading pass improves repeat races; universal half-time target remains (2026-11-06 to 07)
LHF01-LHF05/LHFQ01: Active-owner restoration skips discarded Guest work; silent audio loads only the final selected recording. Existing-budget arbitration keeps expensive effects before road intermediates; two cache annotations remove incidental world imports without changing method bodies/asset guards, and Profile retains its lazy renderer boundary. Quiet desktop Winter warm median1.112to0.662s and Desert1.144to0.794s; Pine0.577to0.604s and ordinary startup5.416to5.473s show no gain. Rivalry picture candidate is rejected/byte-exact archived after same-source180/0 shows Garage1.288to1.896s and totaljourney17.228to17.492s; original live Rivalry and direct Garage remain. Owner12/0, audio8/69, race229/0 plus final Winter28/0 and exact native construction, prepared468/1925/0 and five-picture156-source checks pass. Backend Daily demand keeps worker backoff; SQLite24pass1skip/Ruff pass, no rollout. Approved pinned NDK/Swappy ARM64 engine builds and debug AAR/source ZIP complete,212 archive entries exact/CRC checked and21 package tests pass; no Android profile/performance qualification. Initial failures, rejected graph/cache experiments, cache-state limits, index-metadata refresh and concurrent work are preserved. [Implementation, final menu checks, timings, native images, build outcomes and task-only checkpoint](REPORT_LINK). No device query/test, APK export/install, owner-save/process change, live backend request or deployment; HEAD/staged content unchanged. Device qualification and the half-loading target remain.
"""

for relative in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    path = ROOT / relative
    original = path.read_bytes()
    marker = ("<!-- " + MARKER + " -->").encode()
    if marker in original:
        start = original.index(marker)
        end = original.index(("<!-- /" + MARKER + " -->").encode(), start) + len("<!-- /" + MARKER + " -->")
        while original[end:end+1] in [b"\r", b"\n"]:
            end += 1
        original = original[:start] + original[end:]
    link = "LOADING_HALF_2026_11_06.md" if relative.startswith("docs/") else "docs/LOADING_HALF_2026_11_06.md"
    block = "<!-- " + MARKER + " -->\n" + BODY.replace("REPORT_LINK", link) + "<!-- /" + MARKER + " -->\n\n"
    path.write_bytes(block.encode("utf-8") + original)
    print(relative)

"""Validate the local legal drafts and create aggregate, non-player evidence."""

import csv
import difflib
import hashlib
import io
import json
import re
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
LEGAL = ROOT / "docs/legal"
TERMS = LEGAL / "TERMS_DRAFT.md"
PLAN = LEGAL / "LAUNCH_COMPLIANCE_PLAN.md"
CHECKLIST = LEGAL / "LAUNCH_CHECKLIST.csv"
REVIEW_RESPONSE = LEGAL / "LEGAL_REVIEW_RESPONSE.md"
SECOND_REVIEW_RESPONSE = LEGAL / "SECOND_LEGAL_REVIEW_RESPONSE.md"
PUBLISHER_DECISIONS = LEGAL / "PUBLISHER_DECISIONS_2026_10_25.md"
SOURCE_ARTIFACTS = [EVIDENCE / name for name in ["review-input.txt", "terms-before-user-review.txt", "second-review-input.txt", "terms-before-second-review.txt", "terms-before-publisher-decisions.txt", "terms-before-annual-ad-free.txt"]]
OWNED = [TERMS, PLAN, CHECKLIST, REVIEW_RESPONSE, SECOND_REVIEW_RESPONSE, PUBLISHER_DECISIONS]
SHARED = [ROOT / "docs/README.md", ROOT / "DEVELOPMENT_STATUS.md", ROOT / "docs/PHASE_0_PLAN.md"]
TASK_MARKER = "2026-10-25 LCP01-LCP14/S01/S02/R01/Q01:"
checks = []


def require(name, condition):
    if not condition:
        raise AssertionError(name)
    checks.append({"check": name, "result": "pass"})


def relative(path):
    return path.relative_to(ROOT).as_posix()


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify():
    texts = {path: path.read_text(encoding="utf-8") for path in OWNED + SHARED}
    terms = texts[TERMS]
    plan = texts[PLAN]
    rows = list(csv.DictReader(io.StringIO(texts[CHECKLIST])))
    expected_columns = ["ID", "Area", "Responsible_role", "Status", "Next_action", "Completion_evidence", "Depends_on", "Source"]
    require("CSV columns", list(rows[0]) == expected_columns)
    require("41 unique sequential checklist IDs", [row["ID"] for row in rows] == [f"LCP-{number:02}" for number in range(1, 42)])
    require("CSV has no overflow columns or missing values", all(None not in row and all(row[key] is not None for key in expected_columns) for row in rows))
    required = [key for key in expected_columns if key != "Depends_on"]
    require("Checklist actions owners and evidence are populated", all(all(row[key].strip() for key in required) for row in rows))
    by_id = {row["ID"]: row for row in rows}
    dependencies = {key: [item for item in row["Depends_on"].split(";") if item] for key, row in by_id.items()}
    require("Dependencies refer to known rows", all(dep in by_id for deps in dependencies.values() for dep in deps))
    visiting, visited = set(), set()

    def visit(key):
        if key in visiting:
            raise AssertionError("Checklist dependency cycle")
        if key in visited:
            return
        visiting.add(key)
        for dep in dependencies[key]:
            visit(dep)
        visiting.remove(key)
        visited.add(key)

    for key in dependencies:
        visit(key)
    require("Checklist dependency graph is acyclic", len(visited) == len(rows))
    require("No checklist row claims completion", all(row["Status"] not in {"Complete", "Passed", "Accepted", "Approved"} for row in rows))
    require("Draft is explicitly ineffective", "Not effective or published" in terms and "[TO BE SET AFTER REVIEW]" in terms)

    local_links, external_links = [], set()
    for path in [TERMS, PLAN, REVIEW_RESPONSE, SECOND_REVIEW_RESPONSE, PUBLISHER_DECISIONS]:
        for target in re.findall(r"\]\(([^)]+)\)", texts[path]):
            if target.startswith(("https://", "http://")):
                external_links.add(target)
                continue
            dest = (path.parent / unquote(target.split("#")[0])).resolve()
            require(f"Local link {relative(path)} -> {target}", dest.is_relative_to(ROOT) and dest.exists())
            local_links.append({"from": relative(path), "target": target})
    for row in rows:
        target = row["Source"]
        if target.startswith("https://"):
            external_links.add(target)
        else:
            dest = (LEGAL / target).resolve()
            require(f"Checklist source {row['ID']}", dest.is_relative_to(ROOT) and dest.exists())
    for path in OWNED:
        require(f"UTF8 newline and whitespace {relative(path)}", texts[path].endswith("\n") and all(line == line.rstrip() for line in texts[path].splitlines()))
    for path in SHARED:
        marker = "| Launch compliance and terms |" if path.name == "README.md" else TASK_MARKER
        require(f"Single task entry {relative(path)}", texts[path].count(marker) == 1)

    # Produce a task-only reverse-checkable patch without staging shared work.
    patch_parts = []
    for path in OWNED + SOURCE_ARTIFACTS + [Path(__file__).resolve()] + SHARED:
        after = path.read_text(encoding="utf-8")
        if path not in SHARED:
            before, from_file = "", "/dev/null"
        else:
            own_lines = [line for line in after.splitlines(keepends=True) if "| Launch compliance and terms |" in line or line.startswith(TASK_MARKER)]
            require(f"One own line for patch {relative(path)}", len(own_lines) == 1)
            before = after.replace(own_lines[0], "", 1)
            if path.name != "README.md":
                before = before.replace("# Development status and checkpoint history\n\n\n", "# Development status and checkpoint history\n\n", 1)
                before = before.replace("# Original plan and implementation checkpoints\n\n\n", "# Original plan and implementation checkpoints\n\n", 1)
            from_file = "a/" + relative(path)
        for line in difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile=from_file, tofile="b/" + relative(path)):
            patch_parts.append(line)
            if not line.endswith("\n"):
                patch_parts.append("\n\\ No newline at end of file\n")
    patch_path = EVIDENCE / "checkpoint.patch"
    patch_path.write_text("".join(patch_parts), encoding="utf-8", newline="\n")
    result = subprocess.run(["git", "apply", "--check", "--reverse", str(patch_path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    require("Task-only checkpoint reverse application check", result.returncode == 0)
    result = subprocess.run(["git", "diff", "--check", "--", *map(relative, OWNED + SHARED)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    require("Scoped git diff whitespace check", result.returncode == 0)

    report = {
        "task": "LCP01-LCP14/S01/S02/R01/Q01",
        "prepared_for_date": "2026-10-24",
        "refined_for_date": "2026-10-25",
        "terms_version": "bmt-terms-draft-2026-10-25-r6",
        "verification_utc": datetime.now(timezone.utc).isoformat(),
        "status": "drafts_prepared_not_effective_or_published",
        "scope": "Repository legal drafts, concrete launch plan and acceptance checklist; no runtime change",
        "owner_confirmed_policy": "Operational/commercial discontinuation may be global or geographical including unsustainable regulatory compliance; at least 60 days in-game notice selected for planned withdrawal with longer or additional notice required by law and existing urgent exceptions; no live withdrawal or geographic block requested",
        "owner_confirmed_audience": {"minimum_age": 13, "initial_regions": ["EU", "US", "Canada"], "regional_parental_and_language_processes": "outstanding"},
        "owner_confirmed_succession": "Reserve sale or licensing of transferable game IP and successor maintenance development and operation, subject to lawful contract assignment and data handling; no transaction requested",
        "owner_confirmed_development": "Reserve substantial gameplay modifications with identified valid reasons and mandatory protections; current runtime and product invariants unchanged",
        "conduct_policy_draft": "Express proportionate temporary and permanent bans for offensive names/content and other material misconduct; no discretionary goodwill refund solely for justified enforcement; mandatory complaint refund and redress rights preserved; no live sanction requested",
        "published_track_policy_draft": "Creator cannot edit replace hide delete or withdraw a publication; changed layouts require a separate track and slot; continuing commercial adaptation promotion and successor permissions retain mandatory and legacy rights; separately versioned publisher adaptations cannot silently replace pinned race identities; runtime policy alignment and agreement not implemented",
        "purchase_deletion_policy_draft": "Selected contractual interpretation ends all account-bound paid benefits including remaining annual or monthly ad-free on informed voluntary whole-account deletion without new-account carry-over; reinstall on the same existing account retains unexpired access; no blanket Google transfer duty is asserted; mandatory consumer and store remedies retained with normal regional review and provider-state handling",
        "annual_ad_free_decision": "Replace proposed permanent ad-free with twelve months paid once without automatic renewal and an exact displayed expiry; prices and provider configuration remain open; actual forever SKU flag annual grants verification expiry and ordinary recovery need engineering; no runtime change or retroactive conversion of existing rights",
        "publishing_economy_decisions": "One initial free slot confirmed as an abuse deterrent; no creator revision of existing publication; possible race-reward slots do not establish a promised or implemented reward schedule; final products and prices undecided",
        "translation_preference": "AI-assisted translation preferred; complete legal and UI scope version meaning and required language-delivery checks plus support languages remain open; no translations generated or accepted by this task",
        "operator_assignment": "Publisher tentatively expects to handle initial operations personally; coverage secure access and escalation remain unverified; no backup person or support SLA appointed",
        "additional_source_findings": "Publication commit can add versions under the same logical authoring identity and owner hide endpoint exists, requiring alignment with the selected immutable policy; local automated naming filter and ad/resume rules remain source facts rather than production acceptance",
        "command": ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/launch-compliance-2026-10-24/verify_documents.py",
        "checks": checks,
        "check_count": len(checks),
        "checklist_rows": len(rows),
        "status_counts": dict(Counter(row["Status"] for row in rows)),
        "terms_word_count": len(terms.split()),
        "before_review_word_count": len(SOURCE_ARTIFACTS[1].read_text(encoding="utf-8").split()),
        "before_second_review_word_count": len(SOURCE_ARTIFACTS[3].read_text(encoding="utf-8").split()),
        "before_publisher_decisions_word_count": len(SOURCE_ARTIFACTS[4].read_text(encoding="utf-8").split()),
        "before_annual_decision_word_count": len(SOURCE_ARTIFACTS[5].read_text(encoding="utf-8").split()),
        "review_status": "Both informal reviews retained historically and superseding publisher answers incorporated; no retained-counsel sign-off validation of selected purchase-loss policy or publication acceptance",
        "verification_notes": ["Initial reverse-check attempt found the preserved review input has no final newline; patch generation now records that exact EOF state without altering the supplied review bytes"],
        "unresolved_draft_fields": sorted(set(re.findall(r"\*\*\[([^\]]+)\]\*\*", terms))),
        "local_markdown_links": local_links,
        "primary_source_urls": sorted(external_links),
        "source_sha256": {relative(path): sha256(path) for path in OWNED + SOURCE_ARTIFACTS + [Path(__file__).resolve()]},
        "product_source_sha256": {path: sha256(ROOT / path) for path in ["backend/bmt_backend/commerce.py", "backend/bmt_backend/commerce_models.py", "backend/bmt_backend/publications.py", "backend/bmt_backend/tracks.py", "backend/bmt_backend/resumes.py", "backend/bmt_backend/privacy.py", "backend/bmt_backend/community.py", "backend/bmt_backend/name_moderation.py", "backend/bmt_backend/provider_proofs.py", "backend/bmt_backend/runs.py", "backend/bmt_backend/worker.py", "backend/bmt_backend/verifier.py", "backend/bmt_backend/trajectory_verifier.py", "game/backend/track_lifecycle.gd", "game/platform/resume_credits.gd", "game/platform/race_ad_breaks.gd", "game/platform/admob_interstitial.gd", "game/platform/admob_test_ads.gd", "game/ui/store_page.gd"]},
        "shared_files": [relative(path) for path in SHARED],
        "checkpoint": {"path": relative(patch_path), "sha256": sha256(patch_path), "reverse_check": "pass", "staged_or_committed": False},
        "limits": [
            "Publisher identity contacts domain prices remaining catalogue choices support languages regional processes and product-specific withdrawal remain open; one-year non-renewing ad-free 13+ EU US Canada initial free slot creator immutability and 60-day in-game notice are selected",
            "No universal restoration requirement after voluntary whole-account deletion is claimed and no legal certification of every forfeiture is given; account-bound loss preserves mandatory claims and requires accurate disclosure and provider-state handling",
            "Source still exposes the proposed forever product and flag; annual provider verification grants expiry no-renewal and ordinary reinstall recovery are not implemented by these document changes",
            "Creator immutability no-hiding publication permissions notice delivery translations and legacy handling remain implementation or acceptance gates rather than runtime changes or effective licences",
            "No lawyer engagement or legal sign-off claimed; substantive review is recommended before publication",
            "Play Console business paperwork and live resource settings were not inspected",
            "External sources were reviewed with web tools, not re-fetched by this local verifier",
            "No runtime UI change, runtime regression suite, phone/tablet attachment check or physical-device test",
            "No APK/AAB export/install, provider transaction, existing account mutation, publication or deployment",
            "Concurrent workspace changes remain outside the task-only checkpoint",
        ],
    }
    (EVIDENCE / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"document_checks": len(checks), "checklist_rows": len(rows), "unresolved_fields": len(report["unresolved_draft_fields"]), "checkpoint_reverse_check": "pass", "report": relative(EVIDENCE / "report.json")}, ensure_ascii=False))


if __name__ == "__main__":
    verify()

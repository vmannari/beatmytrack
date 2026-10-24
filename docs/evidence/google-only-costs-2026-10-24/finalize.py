"""Check the Google-only scenarios and retain a scoped, reviewable checkpoint."""
import difflib
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DOC = ROOT / "docs/GOOGLE_ONLY_COST_OPTIONS_2026_10_24.md"


def main():
    model = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
    profiles = model["managed_profiles"]
    for profile in profiles:
        assert math.isclose(sum(profile["components_eur_month"].values()),
                            profile["subtotal_before_delivery_eur_month"])
    for scenario in model["download_scenarios"]:
        assert scenario["gib_month"] == 1000000 * 30 * scenario["mib_downloaded_per_dau_day"] / 1024
        for i, profile in enumerate(profiles):
            delivery = sum(scenario[key] for key in (
                "actual_split_public_cdn_eur_month", "actual_split_private_cloud_run_egress_eur_month",
                "cdn_fill_at_tenpercent_miss_eur_month"))
            total = profile["subtotal_before_delivery_eur_month"] + delivery + scenario["cdn_lookup_eur_month_range"][i]
            assert math.isclose(total, scenario["managed_budget_with_reporting_eur_month_range"][i])
            saving = scenario["conditional_one_year_commit_covered_compute_saving_eur_month_range"][i]
            assert math.isclose(total - saving, scenario["conditional_commit_budget_eur_month_range"][i])
    links = 0
    for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", DOC.read_text(encoding="utf-8")):
        if not link.startswith(("https://", "http://", "#")):
            assert (DOC.parent / link.split("#")[0]).is_file(), link
            links += 1
    sources = [DOC, *sorted(p for p in HERE.iterdir() if p.suffix in (".json", ".py")
                            and p.name != "report.json")]
    report = {
        "date": "2026-10-24", "requirements": ["GCO01", "GCO02", "GCO03", "GCO04", "GCO05"],
        "status": "Google-only architecture and pricing scenarios prepared; no population capacity claim",
        "checks": {"component_sums": "passed", "delivery_and_commitment_arithmetic": "passed",
                   "json_readback": "passed", "relative_links": links,
                   "runtime_tests": "Not rerun: no runtime changes; current trajectory benchmark reused",
                   "lint_compilation_and_patch": "Run separately; results recorded in conversation"},
        "source_sha256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sources},
        "preservation": {"cloud_calls": "Read-only official public pricing catalogue metadata",
                         "resource_configuration_changes": False, "deployments": False,
                         "purchases": False, "runtime_changes": False, "data_deletions": False},
        "limitations": model["qualifications"],
    }
    (HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    patch = []
    changed = 0
    for path in [*sources, HERE / "report.json"]:
        name = path.relative_to(ROOT).as_posix()
        baseline = subprocess.run(["git", "show", "HEAD:" + name], cwd=ROOT, capture_output=True, check=False)
        before = baseline.stdout.decode("utf-8").splitlines(keepends=True) if baseline.returncode == 0 else []
        after = path.read_text(encoding="utf-8").splitlines(keepends=True)
        if before == after:
            continue
        changed += 1
        patch.append(f"diff --git a/{name} b/{name}\n")
        if baseline.returncode:
            patch.append("new file mode 100644\n")
        patch.extend(difflib.unified_diff(before, after,
                     fromfile="a/" + name if not baseline.returncode else "/dev/null", tofile="b/" + name))
    (HERE / "scoped-change.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
    print(json.dumps({"arithmetic": "passed", "relative_links": links, "checkpoint_files": changed}))


if __name__ == "__main__":
    main()

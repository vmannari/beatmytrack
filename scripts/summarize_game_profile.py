"""Build the review report from retained measurements, never from planned runs."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/game-profile-2026-11-12"


def read(name):
    path = OUT / name
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None


def table(headers, rows):
    return "\n".join(["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |", *["| " + " | ".join(map(str, row)) + " |" for row in rows]])


def preferred(*names):
    for name in names:
        value = read(name + "-metrics.json")
        if value is not None:
            return name, value
    return "", None


data = {"environment": read("environment.json"), "receipts": {}}
for p in OUT.glob("*-receipt.json"):
    receipt = json.loads(p.read_text())
    receipt["diagnostic_line_count"] = len(receipt.get("diagnostics",[]))
    receipt["diagnostics"] = list(dict.fromkeys(receipt.get("diagnostics",[])))
    data["receipts"][p.stem.removesuffix("-receipt")] = receipt
sections = ["# Game profiling — 12 November 2026", "Measured local debug-engine behavior on the current code snapshot. This is a profiling review; production game code, handling, quality defaults and player saves were not edited.",
"Requirements: PRF01 startup; PRF02 menu loading and navigation; PRF03 race loading and retry; PRF04 real driving frame times; PRF05 track editor; PRF06 reproducibility and limitations.",
"## Measurement conditions", "Windows build 26300; Intel Core i7-11700K, 16 logical CPUs; NVIDIA RTX 3090. Pinned official Godot 4.7.2 (`ed1daf0bf`), 1280×720 native rendered windows positioned outside the desktop. Compatibility uses OpenGL; desktop Mobile uses Vulkan. Processes run sequentially. Private APPDATA/LOCALAPPDATA, explicit empty backend URL, offline race fixtures, Dummy audio driver and music disabled. Driving uses uncapped frame rate, disabled VSync, normal Auto graphics, stock approved simpler car models, real AI simulation, a complete countdown, two seconds of warmup and ten seconds of sampling per case. FPS is measured frame-loop throughput, not a physical-display presentation trace.",
"Cold means first use in a fresh profiling process/private application profile, with existing project imports and OS/driver caches. It is not a disk-cache purge or first install. Restart startup reuses its private profile. Warm page entries and race re-entries occur in the same process. Raw timing includes rendered completion where the probe supports it; race loading excludes the three-second countdown and the separately recorded track compilation. Menu ready times include navigation settling, which can exceed first draw.",
"The drive initially had about 345 MiB free after an unsuccessful full-copy attempt. Exploratory code/native libraries were copied while assets were first shared by junction and then NTFS hardlinks; concurrent in-place asset writes remained visible. Later, free space recovered and all 25,378 asset/import/identity files were copied and checked with zero copy-time changes. Final `-final` / `-qualified` runs use private assets and imports, with before/after SHA-256 receipts. Other workspace work was active and its processes were not stopped. These are local debug-engine diagnostics, not an uncontended release benchmark or Android qualification.",
"## Startup"]
startup_rows = []
for name in ("startup-cold", "startup-isolated-cold", "startup-isolated-repeat", "startup-final-cold", "startup-final-repeat", "startup-frozen-cold", "startup-frozen-repeat"):
    d = read(name + "-metrics.json")
    if d:
        startup_rows.append([name, f"{d['engine_to_menu_ms']/1000:.3f}", f"{d['resource_ms']:.1f}", f"{d['initialization_ms']:.1f}", str(d["network_disabled"])])
sections += [table(["Run", "Engine to drawn menu (s)", "App graph load (ms)", "App initialization (ms)", "Offline"], startup_rows),
"The account menu is the ordinary unsigned-in startup destination. These startup probes deliberately avoid parsing the heavy game graph before loading App. The first live run and initial shared-asset snapshot runs have concurrency changes in their receipts; retain them as observations, not stable-build comparisons.", "## Menu loading"]
for renderer in ("gl", "mobile"):
    name, d = preferred("menus-" + renderer + "-final-fixed", "menus-" + renderer + "-final", "menus-" + renderer)
    if not d:
        continue
    data[name] = d
    cold = {r["page"]: r for r in d["menus"] if r["cycle"] == 0}
    warm = {r["page"]: r for r in d["menus"] if r["cycle"] == 1}
    rows = [[page, f"{row['ready_ms']/1000:.3f}", f"{warm[page]['ready_ms']:.1f}", f"{row['max_frame_ms']:.1f}", f"{warm[page]['max_frame_ms']:.1f}"] for page, row in cold.items()]
    sections += [f"### {renderer} — {d['checks']} checks, {d['failures']} failures", table(["Page", "First ready (s)", "Repeat ready (ms)", "First worst frame (ms)", "Repeat worst frame (ms)"], rows),
                 "First feature resource loads (ms): " + "; ".join(f"{p.split('/')[-1]} {v:.1f}" for p, v in d["feature_load_ms"].items()) + "."]
nav = OUT / "navigation-gl/profile.json"
if nav.exists():
    d = json.loads(nav.read_text())
    data["navigation-gl"] = d
    sections += ["### Actual navigation with saved custom liveries", "This separate scenario invokes `_navigate_menu_page`, including neighbor promotion and background preparation, and samples 80 frames per action. Its preloaded App graph means it is not another startup benchmark.", table(["Destination", "Handler (ms)", "p95 frame (ms)", "Worst frame (ms)", "Frames >50 ms"], [[r["destination"],f"{r['call_ms']:.2f}",f"{r['p95_ms']:.2f}",f"{r['max_ms']:.2f}",r["over_50ms"]] for r in d["transitions"]])]
sections += ["## Race loading", "The Star spline circuit is the larger loading workload; Grass, Desert and Winter each have a first load and same-process re-entry. The original installation, full countdown, five-lap rules, cover-release and retry-reuse assertions remain in the probe. This is offline preparation; network tickets, downloads and verification latency are excluded."]
for renderer in ("gl", "mobile"):
    name, d = preferred("races-" + renderer + "-final", "races-" + renderer)
    if not d:
        continue
    data[name] = d
    sections += [f"### {renderer} — {d['checks']} checks, {d['failures']} failures", table(["Biome", "Entry", "Load (s)", "Worst frame (ms)", "Retry (ms)", "Compile before entry (ms)"], [[r["theme"],"first" if r["cycle"] == 0 else "repeat",f"{r['wall_ms']/1000:.3f}",f"{r['max_frame_ms']:.1f}",f"{r['retry_ms']:.1f}",f"{r['compile_ms_before_race']:.1f}"] for r in d["samples"]])]
    phases = []
    for r in d["samples"]:
        marks = {m["name"]:m["us"] for m in r["marks"]}
        pairs = [("roads_begin","roads_end"),("game_begin","game_end"),("graphics_begin","graphics_end"),("effects_begin","effects_end")]
        phases.append([r["theme"],r["cycle"],*[f"{(marks[b]-marks[a])/1000:.1f}" if a in marks and b in marks else "—" for a,b in pairs]])
    sections += [table(["Biome","Cycle","Road preparation (ms)","Game construction (ms)","Covered world graphics (ms)","Effects/final finish (ms)"],phases), "Phase hooks are timestamps in an in-memory copy of the shipping controller. They do not modify the production source. Covered graphics and final effects include rendering waits and possible compilation; they are not pure CPU timings."]
sections += ["## Driving FPS and frame pacing", "The verified oval is a separate, smaller gameplay workload. Every biome uses Rally; the other five cars are sampled on Grass. These broad matrices are exploratory runs that overlapped asset writes and disk housekeeping; the three final cache-matched driving checks appear below. Renderer ranges are observations, not a controlled renderer speedup comparison. The short samples cover opening driving segments, not full laps or all high-speed/contact/effect cases. Per-frame script counter costs are averages across rendered frames and include AI driving; CPU, render and GPU times overlap and must not be added together. The existing broad car/presentation timer spans several nested audio/weathering/contact tasks, so those counter values also overlap. A tick-progress guard requires at least 90% of elapsed-time simulation progress; rows with failures are not qualified as real-time driving. No FPS is inferred from headless execution."]
for renderer in ("gl", "mobile"):
    name, d = preferred("driving-" + renderer + "-fixed", "driving-" + renderer)
    if not d:
        continue
    data[name] = d
    sections += [f"### {renderer} — {d['failures']} progress failures",table(["Car / biome","FPS","p50 / p95 / p99 (ms)","Worst (ms)","Frames >33.3 ms","GPU p95 (ms)","Simulated ticks"], [[r["vehicle"]+" / "+r["theme"],f"{r['fps']:.1f}"," / ".join(f"{r['frame_ms'][q]:.2f}" for q in ("p50","p95","p99")),f"{r['frame_ms']['max']:.2f}",r["frame_ms"]["over_33_333"],f"{r['gpu_ms'].get('p95',0):.2f}",r["ticks"]] for r in d["rows"]])]
    costs = []
    for r in d["rows"]:
        c = r["callback_costs"]
        costs.append([r["vehicle"]+" / "+r["theme"],f"{c['physics_total_ms_per_frame']:.3f}",f"{c['process_total_ms_per_frame']:.3f}",f"{c['sim_ms_per_frame']:.3f}",f"{c['ai_ms_per_frame']:.3f}",f"{r['static_bytes']/1048576:.1f}",f"{r['video_bytes']/1048576:.1f}"])
    sections += [table(["Car / biome","Physics callback ms/frame","Presentation callback ms/frame","Simulation ms/frame","AI ms/frame","Godot static MiB","Reported video MiB"], costs), "Static allocation and video-memory monitors are not process RSS or Android PSS. Ten-second samples do not measure long-run memory drift, battery use, thermal throttling or all track/effect combinations. Native gameplay screenshots accompany the rows."]
sections += ["## Track editor"]
for renderer in ("gl", "mobile"):
    folder = next((OUT / n for n in ("editor-"+renderer+"-final","editor-"+renderer+"-fixed","editor-"+renderer) if (OUT/n/("results-gl_compatibility.json" if renderer == "gl" else "results-mobile.json")).exists()),None)
    if folder is None:
        continue
    p = folder / ("results-gl_compatibility.json" if renderer == "gl" else "results-mobile.json")
    d = json.loads(p.read_text())
    data[folder.name] = d
    rows = []
    for r in d["rows"]:
        if r["operation"] == "editor_open": rows.append(["open "+r["theme"]+" "+str(r["pieces"])+" roads / "+str(r["objects"])+" objects",f"{r['ready_ms']:.1f}",f"{r.get('frame',{}).get('max_ms',0):.1f}"])
        elif "ms" in r: rows.append([r["operation"],f"{r['ms']:.1f}","—"])
        elif "handler" in r: rows.append([r["operation"]+" handler p95",f"{r['handler']['p95_ms']:.2f}",f"{r['synthetic_event_to_frame']['max_ms']:.1f}"])
    sections += [f"### {renderer} — {d['checks']} checks, {d['failures']} failures",table(["Operation","Time (ms)","Worst observed frame/event-to-frame (ms)"],rows)]
sections += ["The editor workload includes a 96-road circuit, width editing, 120 synthetic drag updates, undo/redo, two practice entries/returns, 95 authored sheds, overview/detail rendering and Winter surface changes. It retains the original scene-identity, authored-data, history, ownership and cancellation assertions. Synthetic event-to-frame time is not physical touch latency. This refers to the game's track editor; the Godot IDE was not profiled.",
"## Prepared-asset qualification and corrected measurements", "Preliminary runs overlapped in-place asset rebuilds. A live-versus-snapshot source comparison found only the generated build identity and an offline baking test had changed. The old generated cache revisions could reject newly rebuilt prepared scenes even though authored runtime geometry sources matched. Thus the early Vulkan repeat-car/practice times are observations of a stale development cache, not evidence of a general renderer regression. The initial identity and the snapshot-only refresh receipt are preserved. Once space became available, all runtime assets were detached from hardlinks into private copies, imported resources were copied and their verified junction was removed, and snapshot identity/project version were refreshed together. The final loading/menu/editor passes use that complete private copy. No live source or asset was changed by these adaptations."]
qualified = read("assets-qualified-metrics.json")
if qualified:
    data["assets-qualified"] = qualified
    sections += [table(["Car","Prepared key matches","Authored source hashes match","Different source paths"],[[r["car"],r["key_matches"],r["source_hashes_match"],", ".join(r["different_sources"])] for r in qualified["rows"]])]
qd = read("driving-mobile-qualified-metrics.json")
if qd:
    data["driving-mobile-qualified"] = qd
    sections += ["Cache-matched driving cross-check (same uncapped 720p workload):",table(["Car / biome","FPS","p95 frame (ms)","Modular base cache hits during load","Progress failures"],[[r["vehicle"]+" / "+r["theme"],f"{r['fps']:.1f}",f"{r['frame_ms']['p95']:.2f}",r.get("modular_base_hits_during_load","—"),qd["failures"]] for r in qd["rows"]])]
sections += [
"## Findings and next work", "First-use work and frame stalls should be investigated before assuming steady driving FPS is the primary problem. The measurements separate script/dependency loading, construction, covered rendering and final effects. Rivalry's feature graph alone takes seconds, while its much longer first frame indicates additional first-render cost. Garage spends many seconds reaching a prepared showroom even after its feature script has loaded. Race re-entry and retry already benefit strongly from retained state. Warm navigation still has isolated frames above a 60 Hz budget; the actual-navigation scenario distinguishes retained-neighbor behavior from direct page construction. These are measured priorities and source-based hypotheses, not implemented optimizations.",
"## Validation, retained failures and limits", "The initial full snapshot failed with no disk space; only that task-owned incomplete copy was removed. Hardware WMI reads were denied; CPU identification came from the read-only Windows processor registry and the renderer identified the GPU. The initial gameplay fixture omitted the offline fixture's required published-track marker, so no game was installed and that run exited 1. The initial editor fixture inherited a synchronous page-open helper that no longer waited for lazy feature loading; it logged script errors and was rejected. The dedicated probe adapters were corrected without changing runtime code or weakening the original assertions. Initial failed receipts remain alongside corrected runs.",
"All native runs retain the sandbox's root-certificate-store diagnostic. Online configuration was explicitly disabled, so the report does not claim TLS or online-path validation. Other shutdown/resource diagnostics are listed verbatim in each receipt and must not be read as clean exits merely because a measurement file exists. Source/asset guard changes cause a nonzero runner status even when functional assertions pass. Initial menu/race runs overlap external asset writes; the full receipts identify every changed path. The report does not claim one immutable binary build or a whole-tree release gate.",
"The first frozen Vulkan menu pass exposed another stale profiler assumption: an adopted `garage_preloaded_studio.gd` has `prepared`/`warming` fields, rather than the cooperative showroom's `preparing` field. That pass logged script errors and was rejected. The dedicated menu adapter retains the original cover/readiness checks for both studio types. Sandboxed termination of that owned failed test was denied; automatic approval review allowed termination of only its recorded process tree, and cleanup succeeded. Later runner code stops the sequence if owned-process cleanup is denied.",
table(["Run","Engine exit","Changed files","Distinct diagnostics","Wall seconds"],[[name,r.get("exit_code"),len(r.get("source_changes",[])),len(r.get("diagnostics",[])),r.get("wall_seconds","—")] for name,r in sorted(data["receipts"].items())]),
"No physical device was queried or tested. No APK/export, deployment, backend request, owner save/process change, main-index write or physics change was performed. Remaining qualification: uncontended stable-asset repetitions with more free disk space, packed release measurements, signed-in data/network cases, representative saved/fitted cars and large tracks, physical-device frame-time/thermal/memory runs and owner interaction review.",
"## Files and reproduction", "New source: `scripts/prepare_game_profile.py`, `scripts/profile_game_overview.py`, `scripts/profile_game_suite.py`, `scripts/summarize_game_profile.py`, `game/tests/profile_overview_driving.gd`, and `game/tests/profile_overview_editor.gd`. The runner invokes `scripts/run_no_crash_dialog.py` for automated Godot process trees, pins `godot-version.txt`, bounds each process, retains raw logs/commands/hashes, and cleans only its completed private shader cache. Existing production scripts and existing regression fixtures were not edited.",
"Additional source: `scripts/freeze_game_profile_assets.py`, `scripts/profile_game_final_suite.py`, `game/tests/profile_overview_assets.gd` and `game/tests/profile_overview_menus.gd`. Disk-pressure housekeeping is recorded in `maintenance.json`; only task-owned copied files, evidence and private shader caches were compressed/cleaned. That housekeeping and external writers overlapped exploratory samples and are additional reasons not to treat the exploratory renderer comparison as uncontended. Final cache-matched passes are labeled with `-final` or `-qualified`; earlier raw results remain available.",
"Raw results and exact commands: [evidence directory](evidence/game-profile-2026-11-12/), especially `*-receipt.json`, `*-process.json`, `*-sources.json`, `*-metrics.json`, native capture folders, `environment.json`, `snapshot-manifest.json` and `frozen-assets.json`. The combined machine-readable result is [summary.json](evidence/game-profile-2026-11-12/summary.json). The task's new source/report delta is reviewable in [source-only.patch](evidence/game-profile-2026-11-12/source-only.patch), with hashes and reverse-apply validation in `source-checkpoint.json`. Commands actually executed are listed in the receipts, including any `--themes`, `--cycles`, `--renderer`, profile reuse and navigation-output arguments. Re-run one probe through `python scripts/profile_game_overview.py NAME res://tests/PROBE.gd --renderer gl_compatibility`; use `mobile` for desktop Vulkan. Startup pairs must share `--profile NAME`. Prepare a fresh verified snapshot before reproduction; the retained snapshot contains the measured runtime sources."]
headline = []
cold, warm = read("startup-frozen-cold-metrics.json"), read("startup-frozen-repeat-metrics.json")
if cold and warm:
    headline.append(["Startup",f"{cold['engine_to_menu_ms']/1000:.2f} s",f"{warm['engine_to_menu_ms']/1000:.2f} s after process restart"])
for renderer in ("gl","mobile"):
    _, menu = preferred("menus-"+renderer+"-final-fixed","menus-"+renderer+"-final")
    if menu:
        for page in ("rivalry","garage","create"):
            a = next(r for r in menu["menus"] if r["page"]==page and r["cycle"]==0)
            b = next(r for r in menu["menus"] if r["page"]==page and r["cycle"]==1)
            headline.append([renderer+" / "+page,f"{a['ready_ms']/1000:.2f} s first entry",f"{b['ready_ms']:.0f} ms repeat"])
    race = read("races-"+renderer+"-final-metrics.json")
    if race:
        first = [r["wall_ms"] for r in race["samples"] if r["cycle"]==0]
        repeat = [r["wall_ms"] for r in race["samples"] if r["cycle"]==1]
        headline.append([renderer+" / race loading",f"{min(first)/1000:.1f}–{max(first)/1000:.1f} s first entry",f"{min(repeat)/1000:.2f}–{max(repeat)/1000:.2f} s repeat"])
if qd:
    headline.append(["Vulkan / matched driving",f"{min(r['fps'] for r in qd['rows']):.0f}–{max(r['fps'] for r in qd['rows']):.0f} FPS",f"p95 frame {min(r['frame_ms']['p95'] for r in qd['rows']):.2f}–{max(r['frame_ms']['p95'] for r in qd['rows']):.2f} ms"])
if headline:
    sections[2:2] = ["First-use loading and frame stalls dominate this desktop profile. Final copied-asset results:",table(["Workload","First use / throughput","Repeat / pacing"],headline)]
(OUT / "summary.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
(ROOT / "docs/GAME_PROFILE_2026_11_12.md").write_text("\n\n".join(sections)+"\n",encoding="utf-8")
print("Wrote docs/GAME_PROFILE_2026_11_12.md and combined summary.json")

"""Summarize observed CPU/render boundaries; retain slow intervals, not disposable profiles."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/loading-investigation-2026-11-12"


def load_runs():
    runs = {}
    for path in OUT.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        if "events" in data and "rows" in data:
            runs[path.stem] = data
    return runs


def pairs(events, first, last):
    result = []
    opened = None
    for event in events:
        if event["label"] == first:
            opened = event
        elif event["label"] == last and opened:
            result.append(dict(ms=(event["us"]-opened["us"])/1000, data=opened["data"], begin_us=opened["us"], end_us=event["us"]))
            opened = None
    return result


def elapsed(events, first, last):
    values = pairs(events, first, last)
    return sum(v["ms"] for v in values) if values else None


def phase_summary(data, phase):
    events = [e for e in data["events"] if e["phase"] == phase]
    if not events:
        return {}
    costs = {key.split(":",1)[1]:value for key,value in data["costs"].items() if key.startswith(phase+":")}
    if "frame_summary" in data:
        frames = data["frame_summary"].get(phase,{})
    else:
        raw = [f for f in data["frames"] if f["phase"]==phase and 0<f["render_begin_us"]<=f["end_us"]]
        spans = [(f["end_us"]-f["render_begin_us"])/1000 for f in raw]
        frames = dict(count=len(raw),render_total_ms=sum(spans),render_max_ms=max(spans,default=0))
    batches = pairs(events,"world_draw_begin","world_draw_end")
    reads = pairs(events,"surface_read_begin","surface_read_end")
    keys = [e["data"] for e in events if e["label"]=="outline_key"]
    hulls = [e["data"] for e in events if e["label"]=="outline_end" and e["data"]]
    starts = [e["us"] for e in events if e["label"] in ("race_begin","entry_begin")]
    ends = [e["us"] for e in events if e["label"] in ("race_ready","entry_ready")]
    measured = [e for e in events if (not starts or e["us"]>=starts[0]) and (not ends or e["us"]<=ends[-1])]
    return dict(costs=costs,frames=frames,
                feature_ms=elapsed(measured,"feature_begin","feature_end"),
                roads_ms=elapsed(events,"roads_begin","roads_end"),
                game_ms=elapsed(events,"game_begin","game_end"),
                graphics_ms=elapsed(events,"graphics_begin","graphics_end"),
                finish_ms=elapsed(events,"finish_setup_begin","race_end"),
                effects_ms=elapsed(events,"effects_begin","effects_return"),
                audio_ms=elapsed(events,"audio_configure_begin","audio_configure_end"),
                outline_ms=elapsed(events,"outline_begin","outline_end"),
                surface_read_ms=sum(r["ms"] for r in reads),surface_reads=len(reads),
                surface_read_max_ms=max((r["ms"] for r in reads),default=0),
                outline_keys=keys,outline_hulls=hulls,
                outline_hits=sum(e["label"]=="outline_cache_hit" for e in events),
                outline_misses=sum(e["label"]=="outline_cache_miss" for e in events),
                draw_groups=len(batches),draw_wait_total_ms=sum(b["ms"] for b in batches),
                slow_groups=sorted(batches,key=lambda b:-b["ms"])[:8],
                slow_surface_reads=sorted(reads,key=lambda b:-b["ms"])[:8])


def table(headers, rows):
    return "\n".join(["| "+" | ".join(headers)+" |","| "+" | ".join(["---"]*len(headers))+" |",*["| "+" | ".join(map(str,row))+" |" for row in rows]])


def number(value):
    return "—" if value is None else f"{value:.1f}"


def main(compact=False):
    runs = load_runs()
    results = {}
    for name,data in runs.items():
        results[name] = dict(mode=data["mode"],renderer=data["renderer"],checks=data["checks"],failures=data["failures"],rows=data["rows"],phases={p:phase_summary(data,p) for p in sorted({e["phase"] for e in data["events"]})})
    text = ["# Rivalry entry and race loading investigation — 12 November 2026",
            "RLI01–RLI06: controlled offline reproduction, podium draw ablations, persistent shader-cache controls, per-batch native rendering boundaries, repeated construction attribution and bounded evidence/cleanup. Production runtime sources, rendering defaults, canonical physics and player data were not changed.",
            "The strongest new finding is an ineffective repeated contact-outline cache when prepared model meshes are recreated: Vulkan reads 57 mesh surfaces again, taking 4.85 seconds on the repeat. Holding the existing prepared PackedScene resource keeps mesh IDs stable, makes the unchanged cache hit in 0.34 ms, and produces the exact same hull bytes. Total repeat loading in that control falls from 8.79 to 3.71 seconds. This is a diagnostic retention experiment, not a shipping fix or a proven global memory policy.",
            "## What the experiments establish",
            "Rivalry's large first-entry delay is dominated by the first native draw of its 3D podium, followed by synchronous feature-script loading. Three car widgets are constructed in roughly 0.16 seconds; building them is not the multi-second cost. One rendered podium view retains almost the whole initial delay. Reusing the same private application's shader cache across a fresh process removes most of that draw stall. This points to first-use native renderer/driver program preparation; these tests do not intercept current GL compile/link calls, so they do not assign exact percentages to a specific driver API.",
            "Race loading contains several different costs: lazy script/resource graph loading, first-use world/material drawing, final effect drawing, and a separate repeated vehicle-configuration delay observed on Vulkan. The finer outline/readback probes identify that last cost below. World packing is measured separately in microseconds; a `cache` status label does not identify packing as the cause of a rendering stall.",
            "## Conditions and interpretation",
            "Pinned official Godot 4.7.2, Windows/i7-11700K/RTX 3090, native 1280×720 windows offscreen, Dummy audio, music disabled, private APPDATA/LOCALAPPDATA, explicit disabled backend. GPU probes run sequentially. The prior full private project and imports were reused; runtime script comparison against live source differed only at generated build identity. The measured asset revisions remain pinned to that copy. Timers/observers are injected only into this disposable copy, plus explicitly recorded in-memory timing annotations for contact-outline construction. Every completed run records an unchanged before/after disk-project digest; the contact probe separately records original-file and in-memory annotated source hashes.",
            "Optional Garage background warming is suppressed to isolate these paths. Consequently, repeated mesh lifetime is measured without an unrelated Garage view keeping resources alive. Ordinary navigation/optional retention may mask or alter this cache miss; these durations do not mean every normal race repeat takes nine seconds. The retained-scene control deliberately holds one existing stock Rally PackedScene across two races, without changing mesh data, outline calculation, cache key or lookup conditions. The scene is released after the probe. The reported 1,313,542-byte immediate Godot static-allocation delta is not full process/GPU memory qualification.",
            "Cold means a fresh private application/shader-cache directory, with project imports and uncontrolled OS/driver state already present. Restart controls reuse exactly the same profile. First and second entry inside a process distinguish retained views/worlds. Single fresh-profile ablations are causal diagnostics, not statistical renderer/quality benchmarks. Turning off podium views, sky use, rim light or shadows changes the diagnostic picture and is not proposed as a shipping visual change.",
            "## Rivalry entry"]
    rows=[]
    for name,result in results.items():
        if result["mode"]!="rivalry": continue
        for row in result["rows"]:
            p=result["phases"].get("rivalry-"+str(row["cycle"]),{})
            rows.append([name,row["cycle"],number(row["wall_ms"]),number(p.get("feature_ms")),number(p.get("costs",{}).get("page_build_content",{}).get("total_us",0)/1000),number(p.get("frames",{}).get("render_max_ms"))])
    text += [table(["Run","Entry","Ready ms","Feature loads ms","Page construction ms","Largest native render interval ms"],rows),
             "The zero-view control still constructs all three actual widgets/models, but disables their viewport updates. One-view keeps only the first-ranked viewport active. Remaining UI/composite work still draws. Individual lighting toggles retain the original rig construction and alter use afterward; they did not demonstrate a robust first-entry improvement. They do not prove that every underlying resource was absent from the driver's work.",
             "The native draw boundary uses RenderingServer.frame_pre_draw/frame_post_draw. It measures CPU wall time spent in native frame submission/rendering and associated waits, not pure GPU execution time. Camera fitting/page layout are timed independently. A single native call can exceed the script-side scheduling budget, so spreading three widget constructions across frames cannot by itself guarantee responsive first rendering.",
             "## Race loading"]
    rows=[]
    for name,result in results.items():
        if result["mode"]!="race": continue
        for row in result["rows"]:
            p=result["phases"].get("race-"+str(row["cycle"]),{})
            rows.append([name,row["cycle"],number(row["wall_ms"]),number(p.get("feature_ms")),number(p.get("roads_ms")),number(p.get("game_ms")),number(p.get("graphics_ms")),number(p.get("finish_ms")),p.get("draw_groups")])
    text += [table(["Run","Entry","Ready ms","Feature loads ms","Road stage ms","Game construction ms","World draw stage ms","Final finish ms","Draw batches"],rows),
             "Feature-load totals are restricted to the entry timer's begin/ready markers and cover the App's real lazy resources, including the editor memory-policy dependency. Observer phase/frame/helper aggregates may also include pre-entry and post-exit work and must not be added as exclusive slices of that timer. The standalone probe deliberately avoids preloading game classes before App starts. This exposes script parsing/loading that broader typed test fixtures can warm before their race timer. In-memory outline-detail setup loads that one class before the race and should be used for local function attribution, rather than a cold script-load comparison. Race process-restart controls reuse disk road data as well as shader caches; the separate road/draw stages show both effects.",
             "Graphics preparation's `context`, `geometry_key` and `_material_key` CPU timers are inclusive/nested; do not add them together. Material hashing/context scans must be distinguished from the much longer native draw waits. A batch key describes the script's grouping; it is not a count of actual native shader programs.",
             "## Contact outline and repeated configuration"]
    rows=[]
    for name,result in results.items():
        if result["mode"]!="race": continue
        for phase,p in result["phases"].items():
            if p.get("audio_ms") is None: continue
            rows.append([name,phase,number(p["audio_ms"]),number(p.get("outline_ms")),p.get("outline_hits"),p.get("outline_misses"),p.get("surface_reads"),number(p.get("surface_read_ms")),number(p.get("surface_read_max_ms"))])
    text += [table(["Run","Phase","VehicleAudio.configure ms","VisibleContactAudio.configure ms","Outline hits","Misses","Mesh surface reads","Surface-read total ms","Worst read ms"],rows),
             "The normal contact-outline routine reads rendered mesh arrays with surface_get_arrays and builds a convex hull for presentation contact audio. This is outside canonical simulation. Its bounded cache key includes mesh object identities and transforms. The detailed traces retain key hashes, mesh IDs, pose hashes and hull hashes, allowing repeated misses and actual geometry equality to be checked without changing the cache condition. Surface-read timing includes native readback/synchronisation, not merely numeric hull calculation. The test keeps the original algorithm, cache lookup, eviction and output; it adds only timers/metadata before any race is constructed.",
             "For the stock Rally control, all 57 mesh IDs changed between ordinary race instances; pose hashes were identical, both lookups missed, and both hull hashes were `375508ad217875f9483d22f7d8b7e3c86c4ae358202b5dd7ccdfd758b9d08d4f`. Retaining the source PackedScene made IDs, poses and the entire cache key stable. The second lookup hit and returned that same hull hash with zero surface reads. On OpenGL the corresponding reads cost only about 2–3 ms, so this particular repeated readback issue is much more consequential in the observed Vulkan runs. It does not establish a general renderer speed comparison.",
             "Source locations: `game/vehicle/visible_contact_audio.gd:13` constructs the key and outline; line32 reads the surfaces. `game/vehicle/vehicle_audio.gd:133` calls this work from audio configuration. `game/vehicle/modular_car_base.gd:35` loads the prepared scene into a local reference; this path has no bounded retained PackedScene cache. The existing stock-simple path also bypasses the older fitted/full rest-pose cache. The control establishes a concrete resource-lifetime cause without replacing the outline with a guessed shape or changing canonical contacts.",
             "## Largest world-draw batches"]
    for name in ("race-gl-cold","race-gl-warm","race-mobile","race-gl-outline","race-mobile-outline"):
        if name not in results: continue
        p=results[name]["phases"].get("race-0",{})
        text += ["### "+name,table(["Draw wait ms","Material descriptions","Representative nodes"],[[number(b["ms"]),"; ".join(sorted({m for g in b["data"].get("groups",[]) for m in g.get("materials",[])})),"; ".join(n.rsplit("/",1)[-1] for g in b["data"].get("groups",[]) for n in g.get("nodes",[])[:2])] for b in p.get("slow_groups",[])[:5]])]
        text += ["Measured CPU helpers: "+json.dumps(p.get("costs",{}))+"."]
    receipts={p.stem:json.loads(p.read_text()) for p in OUT.glob("*-receipt.json")}
    text += ["## Limits, failures and next implementation targets",
             "The first instrumented Rivalry run retains a two-object/one-resource shutdown finding. Releasing the local App script and draining the soundtrack node after measurement removes that finding in subsequent runs. A contact-probe anchor check rejected an ambiguous reset anchor before applying its annotations; that attempt remains rejected. One instrumented Vulkan cold race hit the original `Preparing start…` loading deadline; it remains a failed run and is not counted as successful cold readiness. The deadline was not increased or disabled. Raw failed logs/receipts are retained alongside successful controls.",
             "The sandbox's certificate-store diagnostic is retained; offline configuration prevents network testing. Timers/metadata add observation overhead, other owner processes were not stopped, and the differing cold durations are not a controlled renderer speedup claim. The older native GL trace in [NATIVE_SHADER_PREPARATION_2026_10_28.md](NATIVE_SHADER_PREPARATION_2026_10_28.md) identified compile/link calls in an earlier build; it corroborates the mechanism but is not substituted for current API-level measurements.",
             "Priorities for a subsequent implementation: (1) add bounded, version/geometry-fenced prepared-model retention or exact prepared CPU outlines, preserving current pose/fit validation, invalidation and memory-pressure eviction; qualify every car/fitted shape and contact invariant, (2) reduce or prepare first-use podium/world native graphics in an appropriate validated render context, preserving exact appearance and real completion, (3) reduce the synchronous feature dependency graph and move genuinely independent CPU/file work behind existing lifecycle guards. World packing, car triangle reduction and serializing the three podium widgets are not supported as the leading fix by these measurements. Existing view/world retention and persistent shader caching already provide large repeat-entry gains. The retention control also changes other resource/draw reuse, so the entire wall-time difference must not be assigned exclusively to the outline function.",
             table(["Run","Native exit","Unchanged project","Diagnostics"],[[name,r.get("exit_code"),r.get("unchanged"),"; ".join(r.get("diagnostics",[]))] for name,r in sorted(receipts.items())]),
             "## Artifacts, source scope and retention",
             "New source: `game/tests/profile_deep_loading.gd`, `scripts/investigate_loading.py` and `scripts/analyze_loading_investigation.py`. No shipping runtime file was edited. Exact instrumentation anchors, private-copy original/instrumented hashes, process commands, data, failures and project digests are in [the evidence directory](evidence/loading-investigation-2026-11-12/). The machine-readable conclusions are in `summary.json`. Frames are compacted to slow intervals plus exact per-phase render totals; event markers and original measurement rows remain. Selected baseline/diagnostic pictures are retained. Both task-owned build directories, including the full private project, shader caches and test profiles, were removed at completion under the owner retention policy. `cleanup.json` records disposition and the mandatory build-cleaner receipt. Other recent/protected build work remains above the 20 GiB target. The four-file source-only checkpoint records hashes and reverse-apply validation without changing the main index.",
             "Reproduction requires preparing a fresh coherent private copy at the path declared in the runner (the existing prepare/freeze profile helpers provide this), verifying all prepared-asset contracts, then running `python scripts/investigate_loading.py instrument` and `python scripts/investigate_loading.py run NAME --case rivalry|race --renderer gl_compatibility|mobile`. Use `--profile NAME` for a persistent-cache pair, `--podium 0|1|3` for podium controls, `--lighting no_sky|no_rim|no_shadows` for visual diagnostics, `--contact` for the additional in-memory contact timers, and `--retain-scene` for the stock Rally resource-lifetime control. Exact actually executed configurations are recorded in `run-configurations.json`. Do not run concurrent GPU probes. Source snapshots are intentionally not permanent evidence.",
             "No device query/test, APK/export, live service request, deployment, owner-save edit, owner-process change, production renderer/default change or main-index write was performed. Release, uncontended repeats, real signed-in network entry and Android driver/frame/input qualification remain separate."]
    (OUT/"summary.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
    (ROOT/"docs/RIVALRY_RACE_LOADING_INVESTIGATION_2026_11_12.md").write_text("\n\n".join(text)+"\n",encoding="utf-8")
    if compact:
        prior=OUT/"compaction.json"
        compacted=json.loads(prior.read_text()) if prior.exists() else []
        for name,data in runs.items():
            if "frame_summary" in data: continue
            path=OUT/(name+".json")
            before=hashlib.sha256(path.read_bytes()).hexdigest()
            data["frame_summary"]={p:phase_summary(data,p).get("frames",{}) for p in {f["phase"] for f in data["frames"]}}
            data["original_frame_count"]=len(data["frames"])
            data["frames"]=[f for f in data["frames"] if f["end_us"]-f["render_begin_us"]>16667 or f["end_us"]-f["begin_us"]>16667]
            data["retained_frame_scope"]="All slow frame/render intervals above 16.667 ms; exact per-phase native-render totals/counts retained separately"
            path.write_text(json.dumps(data,separators=(",",":")),encoding="utf-8")
            compacted.append(dict(name=name,before_sha256=before,after_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),original_frames=data["original_frame_count"],retained_frames=len(data["frames"])))
        (OUT/"compaction.json").write_text(json.dumps(compacted,indent=2))
    print(json.dumps({n:dict(checks=d["checks"],failures=d["failures"],ms=[round(r["wall_ms"],1) for r in d["rows"]]) for n,d in results.items()}))


if __name__=="__main__":
    parser=argparse.ArgumentParser(); parser.add_argument("--compact",action="store_true")
    main(parser.parse_args().compact)

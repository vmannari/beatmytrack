from pathlib import Path
import difflib, subprocess, json, hashlib
ROOT = Path.cwd()
EVIDENCE = ROOT / "docs/evidence/track-load-improvements-2026-10-14"
BEFORE = EVIDENCE / "before"
BASE = EVIDENCE / "checkpoint-base"
AFTER = EVIDENCE / "checkpoint-final"

def read(path):
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")

def head(path):
    result = subprocess.run(["git", "show", "HEAD:"+path], capture_output=True)
    return result.stdout.decode("utf-8-sig").replace("\r\n", "\n") if result.returncode == 0 else ""

def selected_base(path, selected):
    old = read(BEFORE/path).splitlines(keepends=True)
    new = read(ROOT/path).splitlines(keepends=True)
    result = []
    for tag,a,b,c,d in difflib.SequenceMatcher(None,old,new,autojunk=False).get_opcodes():
        result.extend(old[a:b] if tag != "equal" and selected(a+1) else new[c:d])
    return "".join(result)

paths = [
"game/track/road_mesh_disk_cache.gd", "game/track/native_track_visual.gd",
"game/track/prepared_world_cache.gd", "game/vehicle/prepared_car_cache.gd",
"game/vehicle/prepared_car_cache.gd.uid", "game/vehicle/car_visual.gd",
"game/vehicle/personal_ghost.gd", "game/vehicle/sand_dust.gd",
"game/vehicle/vehicle_audio.gd", "game/vehicle/visible_contact_audio.gd",
"game/core/game.gd", "game/core/app.gd", "game/backend/cloud_tracks.gd",
"game/editor/track_compiler.gd", "game/tests/test_prepared_race_resources.gd",
"game/tests/test_prepared_race_resources.gd.uid", "game/tests/test_large_road_cache.gd",
"game/tests/test_large_road_cache.gd.uid", "game/tests/test_race_preparation_reuse.gd",
"game/tests/test_race_preparation_reuse.gd.uid", "game/tests/test_app.gd",
"game/tests/test_rivalry_start_failure.gd", "game/tests/review_track_loading_2026_10_13.gd",
"docs/TRACK_LOADING_IMPROVEMENTS_2026_10_14.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
patch = []
records = []
for path in paths:
    current = read(ROOT/path)
    if path == "game/core/app.gd":
        own = {744,799,1621,1627,1641,2869,2871,2876,2887,2888,2891,2907,2910,2953,2963,2966,2977,2997,3259}
        base = selected_base(path, lambda line: line in own)
        begin = base.index("\tvar prepared_personal_ghost: PersonalGhost")
        end = base.index("\tvar bridge_preparation",begin)
        base = base[:begin]+base[end:]
        restore = "\tif is_instance_valid(prepared_personal_ghost) and prepared_personal_ghost.mesh != null:\n\t\tprepared_personal_ghost.transform = ghost_pose\n\t\tprepared_personal_ghost.visible = ghost_visible\n"
        assert base.count(restore)==1
        base=base.replace(restore,"")
        typed = '\tvar prepared_hazards: Array[Dictionary] = []\n\tif DisplayServer.get_name() != "headless": prepared_hazards = bridge_preparation.begin_groups(game.get("track_ground"), game.get("camera"), ["race_hazard_rendering"])\n'
        prior = '\tvar prepared_hazards: Array[Dictionary] = bridge_preparation.begin_groups(game.get("track_ground"), game.get("camera"), ["race_hazard_rendering"]) if DisplayServer.get_name() != "headless" else []\n'
        assert base.count(typed)==1
        base=base.replace(typed,prior)
    elif path == "game/track/native_track_visual.gd":
        own={63,74,108,357,363,364,382,584,606,608,611,619,647}
        base=selected_base(path,lambda line: line in own)
    elif path == "game/core/game.gd": base=selected_base(path,lambda line: line!=130)
    elif path == "game/vehicle/car_visual.gd": base=selected_base(path,lambda line: line<300)
    elif path == "game/backend/cloud_tracks.gd": base=selected_base(path,lambda line: line<=548)
    elif path == "game/editor/track_compiler.gd":
        base=current
        for correct,previous in [
            ('if _cancelled(cancelled): return null\n\t\t\tvar piece:', 'if _cancelled(cancelled): return null\t\t\tvar piece:'),
            ('if _cancelled(cancelled): return\n\t\tvar stroke:', 'if _cancelled(cancelled): return\t\tvar stroke:')]:
            assert base.count(correct)==1
            base=base.replace(correct,previous)
    elif path in ["DEVELOPMENT_STATUS.md","docs/PHASE_0_PLAN.md"]: base=read(EVIDENCE/"status-before"/path)
    else: base=read(BEFORE/path) if (BEFORE/path).exists() else head(path)
    if base==current: continue
    bp=BASE/path; bp.parent.mkdir(parents=True,exist_ok=True); bp.write_text(base,encoding="utf-8",newline="\n")
    ap=AFTER/path; ap.parent.mkdir(parents=True,exist_ok=True); ap.write_text(current,encoding="utf-8",newline="\n")
    patch.append("diff --git a/"+path+" b/"+path+"\n")
    if not base: patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(base.splitlines(keepends=True),current.splitlines(keepends=True),fromfile="a/"+path if base else "/dev/null",tofile="b/"+path,n=3))
    records.append({"path":path,"before_sha256":hashlib.sha256(base.encode()).hexdigest(),"final_sha256":hashlib.sha256(current.encode()).hexdigest()})
(EVIDENCE/"task-only.patch").write_text("".join(patch),encoding="utf-8",newline="\n")
(EVIDENCE/"checkpoint-files.json").write_text(json.dumps(records,indent=2)+"\n",encoding="utf-8",newline="\n")
print("Checkpoint",len(records),"files",sum(x.count("\n") for x in patch),"lines")

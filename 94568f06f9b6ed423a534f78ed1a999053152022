"""Prepend the completed task record while retaining every existing entry."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
marker = "CHALLENGER-HELLCAT-20261109"
summary = (
    "CHH01-CHH04: Owner supplies Richerworld's CC-BY Hellcat and requests simplification, opaque windows and no interior. "
    "Original911774tri becomes native22894tri default/41766full; supplied exterior, dense-normal transfer and native round wheels replace the C3. "
    "Cabin floors, rig/studio/packed textures/badges are removed; opaque panes/backing pass exact bright-cabin-probe pixels. "
    "Rally-based198km/h tune, wheel contacts, identity, paint and fitted selections remain. "
    "Geometry27/0, fitted316/0, module/ghost1438/0, prepared physics/replay3677/0, washing1655/0, driving72/0, parser554/0, "
    "native opacity28/0 and actual App13/0 each desktop renderer pass. "
    "Coherent406-input/15-command refresh passes551-resource2267/0 and six-picture157-source checks; normal Rally geometry and20 PNG controls exact. "
    "New creator/source/licence renders verbatim; broad545/1 retains unrelated Kart CRLF-versus-rendered-LF assertion with task-start control. "
    "Original blend/18 canonical controls exact;16-file reverse-checked source checkpoint and34 native resource hashes retained. "
)
receipts = {}
for relative,link in [
    ("AGENTS.md","docs/CHALLENGER_HELLCAT_2026_11_09.md"),
    ("DEVELOPMENT_STATUS.md","docs/CHALLENGER_HELLCAT_2026_11_09.md"),
    ("docs/PHASE_0_PLAN.md","CHALLENGER_HELLCAT_2026_11_09.md"),
]:
    path = ROOT/relative
    before = path.read_bytes()
    text = before.decode("utf-8")
    assert marker not in text
    archive = OUT/"tracking-before"/relative
    archive.parent.mkdir(parents=True,exist_ok=True)
    archive.write_bytes(before)
    prefix = (f"<!-- {marker} -->\n"
        "## Super rally uses the simplified supplied Challenger with opaque windows (2026-11-09)\n\n"
        +summary+f"[Implementation, native views, commands, retained findings and source checkpoint]({link}). "
        "Reload/owner appearance and device qualification remain; no device query/test, APK, owner-save/process change, backend request, deployment or main-index write; concurrent work preserved.\n"
        +f"<!-- /{marker} -->\n\n")
    assert path.read_bytes() == before, "Concurrent tracking update; retry with current input"
    path.write_bytes(prefix.encode("utf-8")+before)
    after = path.read_bytes()
    assert after.endswith(before)
    receipts[relative] = {"before":hashlib.sha256(before).hexdigest(),"after":hashlib.sha256(after).hexdigest(),"original_retained_verbatim":True}
(OUT/"tracking-receipt.json").write_text(json.dumps(receipts,indent=2),encoding="utf-8")
print("CHALLENGER_TRACKING: original text retained in all three task records")

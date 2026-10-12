"""Verify that the actual Android content export excludes native Windows audio."""
from pathlib import Path
import json,zipfile
ROOT=Path(__file__).resolve().parents[1]
archive=ROOT/"build/windows_audio/android-content.zip"
with zipfile.ZipFile(archive) as z:
    names=z.namelist()
    windows=[name for name in names if "platform/windows/" in name or name.endswith(".dll") or name.endswith(".gdextension")]
    assert not windows,windows
    assert "platform/windows_impact_audio.gdc" in names,"safe platform guard must remain available to VehicleAudio"
    assert "vehicle/vehicle_audio.gdc" in names,"ordinary cross-platform vehicle sound code must remain"
    extension_list=[name for name in names if name.endswith("extension_list.cfg")]
    for name in extension_list:
        assert b"platform/windows" not in z.read(name)
report=dict(checks=3+len(extension_list),failures=0,zip_bytes=archive.stat().st_size,files=len(names),windows_files=windows,extension_lists=extension_list,
            limits="Local Android content ZIP only; no APK export/install or physical Android audio test.")
(ROOT/"build/windows_audio/export-review.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(json.dumps(report,indent=2))

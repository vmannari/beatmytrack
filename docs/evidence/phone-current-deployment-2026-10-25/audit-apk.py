from pathlib import Path
import hashlib
import json
import zipfile

work = Path(__file__).resolve().parent
verified = json.loads((work / "verified-build.json").read_text(encoding="utf-8-sig"))
apk = Path(verified["apk_path"])
source = work / "source"
libraries = []
with zipfile.ZipFile(apk) as archive:
    names = archive.namelist()
    for path in sorted((source / "game/platform").rglob("*.so")):
        matches = [name for name in names if name.endswith("/" + path.name)]
        assert len(matches) == 1, (path.name, matches)
        expected = hashlib.sha256(path.read_bytes()).hexdigest()
        actual = hashlib.sha256(archive.read(matches[0])).hexdigest()
        assert actual == expected, path.name
        libraries.append({"source": path.relative_to(source).as_posix(), "apk_entry": matches[0], "sha256": actual})
    assert libraries, "No project Android native libraries verified"
    assert not any(name.startswith("assets/tests/") or name.endswith(".dll") for name in names)
    assert any("electric_car_model" in name for name in names), "Electric car model missing"
    assert any("forklift_model" in name for name in names), "Forklift model missing"
report = {"entries": len(names), "native_libraries_exact": True, "native_library_count": len(libraries), "libraries": libraries, "electric_and_forklift_present": True}
(work / "apk-audit.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in report.items() if key != "libraries"}))

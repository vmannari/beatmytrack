"""Inventory disposable build entries without following Windows reparse points."""
import json
import os
from pathlib import Path


def inspect(path):
    size = 0
    latest = 0
    file_latest = 0
    protected = path.name == ".keep" or path.suffix.lower() in {".keystore", ".jks", ".p12"}
    stack = [str(path)]
    while stack:
        current = stack.pop()
        try:
            stat = os.stat(current, follow_symlinks=False)
            latest = max(latest, stat.st_mtime)
            if getattr(stat, "st_file_attributes", 0) & 1024:
                protected = True
                continue
            if stat.st_mode & 0o170000 == 0o040000:
                with os.scandir(current) as entries:
                    for entry in entries:
                        if entry.name == ".keep" or Path(entry.name).suffix.lower() in {".keystore", ".jks", ".p12"}:
                            protected = True
                        entry_stat = entry.stat(follow_symlinks=False)
                        if getattr(entry_stat, "st_file_attributes", 0) & 1024:
                            # Links are unlinked by the PowerShell deleter, never traversed.
                            pass
                        elif entry.is_dir(follow_symlinks=False):
                            latest = max(latest, entry_stat.st_mtime)
                            stack.append(entry.path)
                        else:
                            latest = max(latest, entry_stat.st_mtime)
                            file_latest = max(file_latest, entry_stat.st_mtime)
                            size += entry_stat.st_size
            else:
                size += stat.st_size
                file_latest = max(file_latest, stat.st_mtime)
        except OSError:
            protected = True
    return dict(path=str(path), bytes=size, latest=latest, fileLatest=file_latest, protected=protected)


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1] / "build"
    if root.is_symlink() or (root.exists() and root.stat().st_file_attributes & 1024):
        raise SystemExit("Refusing a linked build root")
    print(json.dumps([inspect(p) for p in root.iterdir()] if root.exists() else []))

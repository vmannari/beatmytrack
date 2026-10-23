"""Disk-backed continuations: one directory pass, then direct manifest seeks.

Preparation streams names before maintenance takes DB locks. Deletion cannot
shift page offsets; storage rechecks each candidate's current type and age.
"""
import os
import re
import secrets
import stat
import time
from pathlib import Path

TEMPORARY_NAME = re.compile(r"\.pending-[A-Za-z0-9_-]{6,80}(?:\.guard)?")
OBJECT_NAME = re.compile(r"[0-9a-f]{64}\.json")
SCAN_FILE = re.compile(r"([0-9a-f]{32})\.(scan|pending|complete)")
HEADER = b"bmt-local-object-scan-v1\n"
SCAN_DIRECTORY = ".object-scans-v1"
SCAN_TTL_SECONDS = 7 * 86400
MAX_ACTIVE_SCANS = 4
MAX_SCAN_DIRECTORY_ENTRIES = 32
MAX_RECORD_BYTES = 128


def validate_cursor(cursor):
    if cursor is None:
        return
    if not isinstance(cursor, dict):
        raise ValueError("Invalid local object cursor")  # noqa: TRY004 - cursor API uses ValueError
    # Old directory offsets upgrade to one fresh scan. Reinspection is safe;
    # translating the offset would reintroduce the discarded prefix walk.
    if set(cursor) == {"shard", "offset"}:
        if (type(cursor["shard"]) is int and 0 <= cursor["shard"] <= 256
                and type(cursor["offset"]) is int and cursor["offset"] >= 0):
            return
    elif (set(cursor) == {"v", "scan", "offset"} and type(cursor["v"]) is int and cursor["v"] == 1
            and isinstance(cursor["scan"], str) and re.fullmatch(r"[0-9a-f]{32}", cursor["scan"])
            and type(cursor["offset"]) is int and cursor["offset"] >= len(HEADER)):
        return
    raise ValueError("Invalid local object cursor")


def candidates(root, *, maximum_entries=None):
    """Stream validated names; optionally cap all directory entries at startup."""
    inspected = 0
    for shard in range(256):
        directory = root / f"{shard:02x}"
        if directory.is_symlink() or not directory.is_dir():
            continue
        try:
            with os.scandir(directory) as stream:
                for entry in stream:
                    inspected += 1
                    name = entry.name
                    if ((OBJECT_NAME.fullmatch(name) and name.startswith(directory.name)
                         or TEMPORARY_NAME.fullmatch(name)) and entry.is_file(follow_symlinks=False)):
                        yield directory.name, name
                    if maximum_entries is not None and inspected >= maximum_entries:
                        return
        except FileNotFoundError:
            continue


def _directory(root):
    directory = root / SCAN_DIRECTORY
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.is_symlink() or not directory.is_dir():
        raise OSError("Local object scan directory must be a real directory")
    return directory


def _open_regular(path, flags):
    if path.is_symlink():
        raise OSError("Local object scan file must be a regular file")
    fd = os.open(path, flags | getattr(os, "O_NOFOLLOW", 0), 0o600)
    if not stat.S_ISREG(os.fstat(fd).st_mode):
        os.close(fd)
        raise OSError("Local object scan file must be a regular file")
    return fd


def _reclaim(directory, clock):
    """Builder lock held. Reclaim scan artifacts, never object data/unknown files."""
    entries = []
    with os.scandir(directory) as stream:
        for entry in stream:
            entries.append(entry)
            if len(entries) > MAX_SCAN_DIRECTORY_ENTRIES:
                raise OSError("Local object scan directory needs operator inspection")
    complete = {entry.name.removesuffix(".complete") for entry in entries
                if SCAN_FILE.fullmatch(entry.name) and entry.name.endswith(".complete")
                and entry.is_file(follow_symlinks=False)}
    active = 0
    for entry in entries:
        match = SCAN_FILE.fullmatch(entry.name)
        if match is None:
            continue
        if not entry.is_file(follow_symlinks=False):
            raise OSError("Local object scan file must be a regular file")
        if (match[2] != "scan" or match[1] in complete
                or entry.stat(follow_symlinks=False).st_mtime < clock - SCAN_TTL_SECONDS):
            try:
                Path(entry.path).unlink()
            except FileNotFoundError:
                pass
        else:
            active += 1
    if active >= MAX_ACTIVE_SCANS:
        raise OSError("Local object scan capacity reached; resume an existing cursor or wait for expiry")


def prepare_scan(root, cursor, lock_file, sync_directory):
    validate_cursor(cursor)
    if cursor is not None and "scan" in cursor:
        return dict(cursor)
    directory = _directory(root)
    sync_directory(root)
    guard_fd = _open_regular(directory / "builder.lock", os.O_RDWR | os.O_CREAT)
    with os.fdopen(guard_fd, "r+b") as guard:
        if os.fstat(guard.fileno()).st_size == 0:
            guard.write(b"0")
            guard.flush()
        if not lock_file(guard):
            raise OSError("A local object scan is being prepared; retry later")
        _reclaim(directory, time.time())
        token = secrets.token_hex(16)
        pending = directory / (token + ".pending")
        destination = directory / (token + ".scan")
        try:
            fd = _open_regular(pending, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
            with os.fdopen(fd, "wb") as output:
                output.write(HEADER)
                for shard, name in candidates(root):
                    output.write(f"{shard}/{name}\n".encode("ascii"))
                output.flush()
                os.fsync(output.fileno())
            os.replace(pending, destination)
            sync_directory(directory)
        except BaseException:
            pending.unlink(missing_ok=True)
            raise
    return {"v": 1, "scan": token, "offset": len(HEADER)}


def read_page(root, cursor, limit):
    """Read at most limit candidates without directory IO or a prefix traversal."""
    validate_cursor(cursor)
    if type(limit) is not int or not 1 <= limit <= 1000:
        raise ValueError("Invalid local object page limit")
    if cursor is None or "scan" not in cursor:
        raise ValueError("Prepare a local object scan before reading pages")
    directory = _directory(root)
    path = directory / (cursor["scan"] + ".scan")
    try:
        fd = _open_regular(path, os.O_RDONLY)
    except FileNotFoundError as exc:
        raise ValueError("Local object scan expired; restart without a cursor") from exc
    names = []
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if info.st_mtime < time.time() - SCAN_TTL_SECONDS:
            raise ValueError("Local object scan expired; restart without a cursor")
        if stream.read(len(HEADER)) != HEADER or cursor["offset"] > info.st_size:
            raise ValueError("Invalid local object scan or cursor")
        stream.seek(cursor["offset"] - 1)
        if stream.read(1) != b"\n":
            raise ValueError("Invalid local object record boundary")
        for _ in range(limit):
            record = stream.readline(MAX_RECORD_BYTES)
            if not record:
                break
            try:
                shard, name = record.decode("ascii").removesuffix("\n").split("/")
            except (ValueError, UnicodeError) as exc:
                raise ValueError("Invalid local object scan record") from exc
            if (not record.endswith(b"\n") or not re.fullmatch(r"[0-9a-f]{2}", shard)
                    or not (OBJECT_NAME.fullmatch(name) and name.startswith(shard)
                            or TEMPORARY_NAME.fullmatch(name))):
                raise ValueError("Invalid local object scan record")
            names.append((shard, name))
        offset = stream.tell()
        more = bool(stream.read(1))
    if not more:
        # Retain the final page for retries until a fresh scan reclaims it.
        # Completion only permits artifact reclamation, never blob deletion.
        marker = directory / (cursor["scan"] + ".complete")
        try:
            fd = _open_regular(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
        except FileExistsError:
            pass
        else:
            os.close(fd)
    return names, {**cursor, "offset": offset} if more else None

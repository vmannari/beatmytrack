"""Private immutable pack IO. Normal reads retrieve one compressed record range."""
import base64
import hashlib
import os
import re
import stat
import tempfile
from xml.etree import ElementTree


class PackIO:
    def __init__(self, store, maximum):
        self.store, self.maximum = store, maximum

    def key(self, digest):
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid pack digest")
        return f"packs/{digest[:2]}/{digest}.pack"

    def put(self, digest, body):
        if len(body) > self.maximum or hashlib.sha256(body).hexdigest() != digest:
            raise ValueError("Invalid pack bytes")
        store, key = self.store, self.key(digest)
        if hasattr(store, "root"):
            path = store.root / key
            path.parent.mkdir(parents=True, exist_ok=True)
            fd, temporary = tempfile.mkstemp(prefix=".pending-pack-", dir=store.root)
            try:
                with os.fdopen(fd, "wb") as stream:
                    from .storage import lock_temporary
                    if not lock_temporary(stream):
                        raise OSError("Pack temporary file is busy")
                    stream.write(body)
                    stream.flush()
                    os.fsync(stream.fileno())
                if path.exists():
                    if self.get(digest, 0, len(body)) != body:
                        raise OSError("Existing pack differs")
                else:
                    os.replace(temporary, path)
                    from .storage import sync_directory
                    sync_directory(path.parent)
                    sync_directory(path.parent.parent)
                    sync_directory(store.root)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
            return
        key = store.prefix + key
        if hasattr(store, "bucket"):
            status, reply = store._request("POST", upload=True, body=body,
                query={"uploadType": "media", "name": key, "ifGenerationMatch": "0", "fields": "name,size,md5Hash"},
                extra_headers={"Content-Type": "application/octet-stream"})
            if status in (200, 201):
                metadata = store._metadata(reply)
                checksum = base64.b64encode(hashlib.md5(body, usedforsecurity=False).digest()).decode("ascii")
                if metadata.get("name") != key or metadata.get("size") != str(len(body)) or metadata.get("md5Hash") != checksum:
                    raise OSError("Pack acknowledgement failed integrity")
                return
        else:
            status, _ = store._request("PUT", key, body=body, extra={"if-none-match": "*", "content-type": "application/octet-stream"})
            if status in (200, 201):
                return
        if status == 412 and self.get(digest, 0, len(body)) == body:
            return
        raise OSError("Immutable pack upload failed")

    def get(self, digest, offset, length):
        if type(offset) is not int or type(length) is not int or offset < 0 or length <= 0 or offset + length > self.maximum:
            raise ValueError("Invalid pack range")
        store, key = self.store, self.key(digest)
        if hasattr(store, "root"):
            with (store.root / key).open("rb") as stream:
                stream.seek(offset)
                body = stream.read(length)
        else:
            arguments = {"extra_headers": {"Range": f"bytes={offset}-{offset+length-1}"}} if hasattr(store, "bucket") else {
                "extra": {"range": f"bytes={offset}-{offset+length-1}"}}
            status, body = store._request("GET", store.prefix + key, limit=length,
                **({"query": {"alt": "media"}} if hasattr(store, "bucket") else {}), **arguments)
            if status != 206:
                raise OSError("Pack range unavailable")
        if len(body) != length:
            raise OSError("Truncated pack range")
        return body

    def delete(self, digest):
        store, key = self.store, self.key(digest)
        if hasattr(store, "root"):
            (store.root / key).unlink(missing_ok=True)
            return
        if hasattr(store, "bucket"):
            status, reply = store._request("GET", store.prefix + key, query={"fields": "generation,name"})
            if status == 404:
                return
            if status != 200:
                raise OSError("Pack metadata unavailable")
            metadata = store._metadata(reply)
            generation = str(metadata.get("generation", ""))
            if metadata.get("name") != store.prefix + key or not re.fullmatch(r"[1-9][0-9]*", generation):
                raise OSError("Invalid pack generation")
            status, _ = store._request("DELETE", store.prefix + key, query={"ifGenerationMatch": generation})
        else:
            status, _ = store._request("DELETE", store.prefix + key)
        if status not in (200, 204, 404):
            raise OSError("Pack deletion failed")

    def list(self, cursor=None, limit=1000):
        """Physical pack listing for consistent provider backups, not player reads."""
        if type(limit) is not int or not 1 <= limit <= 1000 or (cursor is not None and (type(cursor) is not str or not cursor or len(cursor) > 4096)):
            raise ValueError("Invalid physical pack cursor")
        store = self.store
        prefix = store.prefix + "packs/"
        if hasattr(store, "bucket"):
            query = {"prefix": prefix, "maxResults": str(limit), "fields": "items(name,size),nextPageToken"}
            if cursor:
                query["pageToken"] = cursor
            status, body = store._request("GET", query=query, limit=1024*1024)
            if status != 200:
                raise OSError("Pack listing unavailable")
            value = store._metadata(body)
            entries = [(row.get("name"), row.get("size")) for row in value.get("items", [])]
            following = value.get("nextPageToken")
        else:
            query = {"list-type": "2", "max-keys": str(limit), "prefix": prefix}
            if cursor:
                query["continuation-token"] = cursor
            status, body = store._request("GET", query=query, limit=1024*1024)
            if status != 200:
                raise OSError("Pack listing unavailable")
            value = ElementTree.fromstring(body)
            entries = [(row.findtext("{*}Key"), row.findtext("{*}Size")) for row in value.findall("{*}Contents")]
            following = value.findtext("{*}NextContinuationToken")
        if len(entries) > limit or (following and (not isinstance(following, str) or len(following) > 4096 or following == cursor)):
            raise OSError("Invalid physical pack listing")
        rows = []
        for name, size in entries:
            match = re.fullmatch(re.escape(prefix) + r"([0-9a-f]{2})/([0-9a-f]{64})\.pack", name or "")
            if not match or not match[2].startswith(match[1]) or not 8 <= int(size) <= self.maximum:
                raise OSError("Invalid physical pack entry")
            rows.append({"digest": match[2], "bytes": int(size)})
        return rows, following

    def cleanup_temporary(self, cutoff, limit=100):
        if not hasattr(self.store, "root"):
            return False
        removed = 0
        inspected = 0
        from .storage import lock_temporary
        # Root holds 256 shard directories, not the complete packed-object history.
        with os.scandir(self.store.root) as entries:
            for entry in entries:
                inspected += 1
                if inspected > 1000:
                    break
                if not entry.name.startswith(".pending-pack-") or not entry.is_file(follow_symlinks=False):
                    continue
                if removed >= limit:
                    break
                info = entry.stat(follow_symlinks=False)
                if info.st_mtime >= cutoff:
                    continue
                try:
                    with open(entry.path, "r+b") as stream:
                        current = os.fstat(stream.fileno())
                        if not stat.S_ISREG(current.st_mode) or current.st_mtime >= cutoff or not lock_temporary(stream):
                            continue
                    os.unlink(entry.path)
                    removed += 1
                except FileNotFoundError:
                    continue
        return bool(removed)

"""Native GCS JSON API, ADC identities, conditional immutable writes and bounded IO."""
import base64
import gzip
import hashlib
import io
import json
import re
import threading
from datetime import datetime
from urllib.parse import quote

import google.auth
import requests
from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import Request as AuthRequest
from urllib3.exceptions import HTTPError as StreamError

from .storage import canonical_json

LIMIT = 8 * 1024 * 1024
STORED_LIMIT = LIMIT + 65536
METADATA_LIMIT = 65536
ORIGIN = "https://storage.googleapis.com"


class GCSBlobStore:
    def __init__(self, settings, *, credentials=None, transport=None):
        if not re.fullmatch(r"[a-z0-9][a-z0-9_.-]{1,61}[a-z0-9]", settings.gcs_bucket):
            raise ValueError("Invalid GCS bucket")
        if (not re.fullmatch(r"[A-Za-z0-9_-]+(?:/[A-Za-z0-9_-]+)*", settings.gcs_prefix)
                or len(settings.gcs_prefix) > 256):
            raise ValueError("Invalid GCS prefix")
        self.bucket, self.prefix = settings.gcs_bucket, settings.gcs_prefix + "/"
        self.credentials, self.transport = credentials, transport or requests.request
        self.auth_lock = threading.Lock()
        self.auth_request = None

    def _authentication(self, *args, **kwargs):
        if self.auth_request is None:
            self.auth_request = AuthRequest()
        kwargs["timeout"] = (3, 5)
        return self.auth_request(*args, **kwargs)

    def _headers(self, method, url, *, refresh=False):
        headers = {"Accept-Encoding": "identity"}
        if not self.auth_lock.acquire(timeout=3):
            raise OSError("Object authentication busy")
        try:
            if self.credentials is None:
                self.credentials, _ = google.auth.default(
                    scopes=("https://www.googleapis.com/auth/devstorage.read_write",),
                    request=self._authentication)
            if refresh:
                self.credentials.refresh(self._authentication)
            self.credentials.before_request(self._authentication, method, url, headers)
        except (GoogleAuthError, requests.RequestException, OSError, ValueError):
            raise OSError("Object authentication unavailable") from None
        finally:
            self.auth_lock.release()
        return headers

    def _key(self, digest):
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid object digest")
        return self.prefix + digest[:2] + "/" + digest + ".json"

    def _url(self, key="", *, upload=False):
        base = ORIGIN + ("/upload" if upload else "") + "/storage/v1/b/" + self.bucket + "/o"
        return base + ("/" + quote(key, safe="") if key else "")

    def _request(self, method, key="", *, query=None, body=None, upload=False, limit=METADATA_LIMIT):
        url = self._url(key, upload=upload)
        for attempt in range(2):
            headers = self._headers(method, url, refresh=attempt == 1)
            if body is not None:
                # Store gzip bytes without contentEncoding metadata: avoid provider transcoding.
                headers["Content-Type"] = "application/gzip"
            try:
                with self.transport(method, url, params=query or {}, data=body, headers=headers,
                        stream=True, timeout=(3, 10), allow_redirects=False) as response:
                    data = response.raw.read(limit + 1, decode_content=False)
                    if len(data) > limit:
                        raise OSError("Object response exceeds limit")
                    if response.status_code != 401 or attempt:
                        return response.status_code, data
            except (requests.RequestException, StreamError):
                raise OSError("Object service unavailable") from None
        raise OSError("Object authentication unavailable")

    @staticmethod
    def _metadata(body):
        try:
            value = json.loads(body)
            if type(value) is dict:
                return value
        except (ValueError, UnicodeError, RecursionError):
            pass
        raise OSError("Invalid object metadata")

    def put_json(self, data):
        raw = canonical_json(data)
        if len(raw) > LIMIT:
            raise ValueError("Object exceeds limit")
        digest = hashlib.sha256(raw).hexdigest()
        key = self._key(digest)
        body = gzip.compress(raw, compresslevel=3, mtime=0)
        status, response = self._request("POST", upload=True, body=body,
            query={"uploadType": "media", "name": key, "ifGenerationMatch": "0",
                "fields": "name,generation,size,md5Hash"})
        if status == 412:
            self.get_json(digest)  # An existing immutable key still requires SHA256 integrity.
            return digest
        if status not in (200, 201):
            raise OSError("Immutable object publication failed")
        metadata = self._metadata(response)
        expected_md5 = base64.b64encode(hashlib.md5(body, usedforsecurity=False).digest()).decode("ascii")
        if (metadata.get("name") != key or not re.fullmatch(r"[1-9][0-9]*", str(metadata.get("generation", "")))
                or metadata.get("size") != str(len(body)) or metadata.get("md5Hash") != expected_md5):
            raise OSError("Object publication acknowledgement failed integrity")
        return digest

    def get_json(self, digest):
        status, body = self._request("GET", self._key(digest), query={"alt": "media"}, limit=STORED_LIMIT)
        if status != 200:
            raise OSError("Stored object unavailable")
        try:
            if body.startswith(b"\x1f\x8b"):
                with gzip.GzipFile(fileobj=io.BytesIO(body)) as source:
                    body = source.read(LIMIT + 1)
            if len(body) > LIMIT or hashlib.sha256(body).hexdigest() != digest:
                raise OSError("Object integrity check failed")
            value = json.loads(body)
            if type(value) is not dict:
                raise ValueError("Not an object")
            return value
        except (ValueError, UnicodeError, EOFError, RecursionError):
            raise OSError("Invalid stored object") from None

    def delete(self, digest):
        key = self._key(digest)
        status, body = self._request("GET", key, query={"fields": "generation,name"})
        if status == 404:
            return
        if status != 200:
            raise OSError("Object metadata unavailable for deletion")
        metadata = self._metadata(body)
        generation = metadata.get("generation", "")
        if metadata.get("name") != key or not re.fullmatch(r"[1-9][0-9]*", str(generation)):
            raise OSError("Invalid object generation")
        status, _ = self._request("DELETE", key, query={"ifGenerationMatch": generation})
        if status not in (200, 204, 404):
            raise OSError("Object deletion failed or generation changed")

    def list_objects(self, cursor, limit):
        if (type(limit) is not int or not 1 <= limit <= 1000 or
                (cursor is not None and (type(cursor) is not dict or set(cursor) != {"token"}
                    or type(cursor["token"]) is not str or not cursor["token"] or len(cursor["token"]) > 4096))):
            raise ValueError("Invalid object cursor/limit")
        query = {"prefix": self.prefix, "maxResults": str(limit),
            "fields": "items(name,size,updated),nextPageToken"}
        if cursor:
            query["pageToken"] = cursor["token"]
        status, body = self._request("GET", query=query, limit=1024 * 1024)
        if status != 200:
            raise OSError("Object listing failed")
        metadata = self._metadata(body)
        try:
            items, token = metadata.get("items", []), metadata.get("nextPageToken")
            if (type(items) is not list or len(items) > limit or
                    (token is not None and (type(token) is not str or not token or len(token) > 4096
                        or (cursor and token == cursor["token"])))):
                raise ValueError("Invalid listing shape")
            rows = []
            for item in items:
                if type(item) is not dict:
                    raise ValueError("Invalid listing item")
                match = re.fullmatch(re.escape(self.prefix) + r"([0-9a-f]{2})/([0-9a-f]{64})\.json", item.get("name", ""))
                if not match or not match[2].startswith(match[1]):
                    continue
                size = int(item["size"])
                stamp = datetime.fromisoformat(item["updated"].replace("Z", "+00:00"))
                if not 0 <= size <= STORED_LIMIT or stamp.tzinfo is None:
                    raise ValueError("Invalid listing size/time")
                rows.append({"digest": match[2], "modified": int(stamp.timestamp()), "bytes": size})
            return rows, {"token": token} if token else None
        except (ValueError, TypeError, KeyError, AttributeError):
            raise OSError("Invalid object listing") from None

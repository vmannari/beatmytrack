"""Bounded S3-compatible immutable objects using SigV4 and existing requests transport."""
import gzip
import hashlib
import hmac
import re
from datetime import datetime, timezone
from urllib.parse import quote, urlsplit
from xml.etree import ElementTree

import requests
from urllib3.exceptions import HTTPError as StreamError

from .http_transport import PooledTransport
from .storage import MAX_STORED_BLOB_BYTES, canonical_json, decode_blob_json

LIMIT = 8*1024*1024


def signing_headers(method, url, query, body, region, access, secret, token="", extra=None, timestamp=None):
    """AWS SigV4 canonicalization; fixed clock injection supports the AWS golden vector."""
    stamp = timestamp or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    parts = urlsplit(url)
    payload_hash = hashlib.sha256(body).hexdigest()
    headers = {"host":parts.netloc,"x-amz-date":stamp,"x-amz-content-sha256":payload_hash, **(extra or {})}
    if token:
        headers["x-amz-security-token"] = token
    names = ";".join(sorted(headers))
    canonical_headers = "".join(f"{key}:{headers[key].strip()}\n" for key in sorted(headers))
    encoded_query = "&".join(f"{quote(str(key),safe='-_.~')}={quote(str(value),safe='-_.~')}" for key,value in sorted(query.items()))
    canonical = "\n".join((method,parts.path or "/",encoded_query,canonical_headers,names,payload_hash))
    scope = f"{stamp[:8]}/{region}/s3/aws4_request"
    to_sign = "\n".join(("AWS4-HMAC-SHA256",stamp,scope,hashlib.sha256(canonical.encode()).hexdigest()))
    key = ("AWS4"+secret).encode()
    for item in (stamp[:8],region,"s3","aws4_request"):
        key = hmac.new(key,item.encode(),hashlib.sha256).digest()
    signature = hmac.new(key,to_sign.encode(),hashlib.sha256).hexdigest()
    headers["authorization"] = f"AWS4-HMAC-SHA256 Credential={access}/{scope}, SignedHeaders={names}, Signature={signature}"
    return headers, encoded_query


class S3BlobStore:
    def __init__(self, settings, *, transport=None):
        self.settings = settings
        if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]",settings.s3_bucket):
            raise ValueError("Invalid object bucket")
        if not re.fullmatch(r"[A-Za-z0-9_/-]+",settings.s3_prefix):
            raise ValueError("Invalid object prefix")
        self.base = settings.s3_endpoint.rstrip("/")+"/"+settings.s3_bucket
        self.prefix = settings.s3_prefix.strip("/")+"/"
        self.transport = transport if transport is not None else PooledTransport()
        self.owns_transport = transport is None

    def close(self):
        if self.owns_transport:
            self.transport.close()

    def _key(self, digest):
        if not re.fullmatch(r"[0-9a-f]{64}",digest):
            raise ValueError("Invalid object digest")
        return self.prefix+digest[:2]+"/"+digest+".json"

    def _request(self, method, key="", *, query=None, body=b"", extra=None, limit=LIMIT):
        url = self.base+("/"+quote(key,safe="/-_.~") if key else "")
        headers, encoded = signing_headers(method,url,query or {},body,self.settings.s3_region,
            self.settings.s3_access_key,self.settings.s3_secret_key,self.settings.s3_session_token,extra)
        try:
            with self.transport(method,url+("?"+encoded if encoded else ""),headers=headers,data=body,
                    timeout=(3,10),stream=True,allow_redirects=False) as response:
                data = response.raw.read(limit+1,decode_content=False)
                if len(data) > limit:
                    raise OSError("Object response exceeds limit")
                return response.status_code,data
        except (requests.RequestException, StreamError):
            raise OSError("Object service unavailable") from None

    def put_json(self, data):
        body = canonical_json(data)
        if len(body) > LIMIT:
            raise ValueError("Object exceeds limit")
        digest = hashlib.sha256(body).hexdigest()
        compressed = gzip.compress(body,compresslevel=3,mtime=0)
        for _ in range(2):
            status,_ = self._request("PUT",self._key(digest),body=compressed,extra={"if-none-match":"*"})
            if status in (200,201):
                return digest
            if status == 412:
                self.get_json(digest) # A reused immutable key must still pass integrity.
                return digest
            if status != 409:
                break
        raise OSError("Immutable object publication failed")

    def get_json(self, digest):
        status,body = self._request("GET",self._key(digest),limit=MAX_STORED_BLOB_BYTES)
        if status != 200:
            raise OSError("Stored object unavailable")
        return decode_blob_json(body, digest)

    def delete(self, digest):
        status,_ = self._request("DELETE",self._key(digest))
        if status not in (200,204,404):
            raise OSError("Object deletion failed")

    def list_objects(self, cursor, limit):
        if (cursor and (set(cursor)!={"token"} or type(cursor["token"]) is not str or len(cursor["token"])>4096)) or not 1 <= limit <= 1000:
            raise ValueError("Invalid object cursor/limit")
        query = {"list-type":"2","max-keys":str(limit),"prefix":self.prefix}
        if cursor:
            query["continuation-token"] = cursor["token"]
        status,body = self._request("GET",query=query,limit=1024*1024)
        if status != 200:
            raise OSError("Object listing failed")
        try:
            tree = ElementTree.fromstring(body)
            rows = []
            for item in tree.findall("{*}Contents"):
                key = item.findtext("{*}Key","")
                match = re.fullmatch(re.escape(self.prefix)+r"([0-9a-f]{2})/([0-9a-f]{64})\.json",key)
                if match and match[2].startswith(match[1]):
                    stamp = datetime.fromisoformat(item.findtext("{*}LastModified").replace("Z","+00:00"))
                    rows.append({"digest":match[2],"modified":int(stamp.timestamp()),"bytes":int(item.findtext("{*}Size"))})
            token = tree.findtext("{*}NextContinuationToken")
            if tree.findtext("{*}IsTruncated") == "true" and not token:
                raise ValueError("Missing continuation token")
            return rows,{"token":token} if token else None
        except (ElementTree.ParseError,ValueError,TypeError,AttributeError) as exc:
            raise OSError("Invalid object listing") from exc

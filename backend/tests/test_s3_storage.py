"""Provider adapter integrity/failure contracts; no external account is contacted."""
import gzip
import hashlib
import io
from types import SimpleNamespace

import pytest
import requests

from bmt_backend.s3_storage import S3BlobStore, signing_headers
from bmt_backend.storage import canonical_json


def store():
    return S3BlobStore(SimpleNamespace(s3_bucket="test-fixture",s3_endpoint="https://objects.example.invalid",
        s3_prefix="bmt/v1",s3_region="us-east-1",s3_access_key="fixture",s3_secret_key="fixture",s3_session_token=""))


def test_signing_matches_aws_published_golden_vector():
    # https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sig-v4-header-based-auth.html
    headers, query = signing_headers("GET","https://examplebucket.s3.amazonaws.com/test.txt",{},b"",
        "us-east-1","AKIAIOSFODNN7EXAMPLE","wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        extra={"range":"bytes=0-9"},timestamp="20130524T000000Z")
    assert not query
    assert headers["authorization"].endswith("Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")


def test_conditional_publication_verifies_reused_object_and_bounds_conflict(monkeypatch):
    adapter=store(); value={"immutable":[1,2,3]}; raw=canonical_json(value)
    digest=hashlib.sha256(raw).hexdigest();calls=[]
    def peer(method,key="",**kwargs):
        calls.append(method)
        if method=="PUT":
            assert kwargs["extra"]=={"if-none-match":"*"}
            assert gzip.decompress(kwargs["body"])==raw
            return 409 if len(calls)==1 else 412,b""
        return 200,gzip.compress(raw)
    monkeypatch.setattr(adapter,"_request",peer)
    assert adapter.put_json(value)==digest and calls==["PUT","PUT","GET"]
    monkeypatch.setattr(adapter,"_request",lambda *_a,**_kw:(409,b""))
    with pytest.raises(OSError): adapter.put_json(value)
    monkeypatch.setattr(adapter,"_request",lambda *_a,**_kw:(200,gzip.compress(b"corruption")))
    with pytest.raises(OSError,match="integrity"): adapter.get_json(digest)


def test_transport_is_bounded_and_never_redirects(monkeypatch):
    calls=[]
    class Raw(io.BytesIO):
        def read(self, size=-1, decode_content=False):return super().read(size)
    class Response:
        status_code=307
        raw=Raw(b"x"*1025)
        def __enter__(self):return self
        def __exit__(self,*_args):pass
    def peer(*args,**kwargs):
        calls.append((args,kwargs));return Response()
    monkeypatch.setattr(requests.Session,"request",lambda _self,*a,**kw:peer(*a,**kw))
    with pytest.raises(OSError,match="limit"):store()._request("GET",limit=1024)
    assert calls[0][1]["allow_redirects"] is False and calls[0][1]["timeout"]==(3,10)
    def timeout(*_a,**_kw):raise requests.Timeout()
    monkeypatch.setattr(requests.Session,"request",lambda _self,*a,**kw:timeout(*a,**kw))
    with pytest.raises(OSError,match="unavailable"):store().get_json("a"*64)


def test_listing_scopes_hashes_and_continuation_token(monkeypatch):
    adapter=store();key="a"*64
    xml=f'''<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
      <IsTruncated>true</IsTruncated><NextContinuationToken>next+/=</NextContinuationToken>
      <Contents><Key>bmt/v1/aa/{key}.json</Key><LastModified>2026-01-01T00:00:00Z</LastModified><Size>23</Size></Contents>
      <Contents><Key>outside/{key}.json</Key></Contents></ListBucketResult>'''.encode()
    monkeypatch.setattr(adapter,"_request",lambda *_a,**_kw:(200,xml))
    rows,cursor=adapter.list_objects(None,20)
    assert len(rows)==1 and rows[0]["digest"]==key and cursor=={"token":"next+/="}
    _,query=signing_headers("GET","https://test.invalid",{"continuation-token":cursor["token"]},b"","x","x","x")
    assert query=="continuation-token=next%2B%2F%3D"
    with pytest.raises(ValueError):adapter.list_objects({"token":"x"*4097},20)


def test_provider_archive_roundtrips_into_local_storage(tmp_path,monkeypatch):
    import importlib.util
    import sys
    import tarfile
    from pathlib import Path

    from bmt_backend.storage import LocalBlobStore
    path=Path(__file__).parents[1]/"deploy/object_archive.py"
    spec=importlib.util.spec_from_file_location("object_archive_fixture",path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    source=LocalBlobStore(str(tmp_path/"source"));value={"portable-provider-object":[1,2,3]*1000}
    key=source.put_json(value);output=io.BytesIO()
    monkeypatch.setattr(sys,"stdout",SimpleNamespace(buffer=output))
    module.archive_objects(source)
    with tarfile.open(fileobj=io.BytesIO(output.getvalue()),mode="r:") as archive:
        entry=archive.getmembers()[0]
        assert entry.name==key[:2]+"/"+key+".json" and entry.isfile()
        restored=LocalBlobStore(str(tmp_path/"restored"))
        restored._path(key).parent.mkdir(parents=True)
        restored._path(key).write_bytes(archive.extractfile(entry).read())
    assert restored.get_json(key)==value

from concurrent.futures import ThreadPoolExecutor

import pytest

from bmt_backend.storage import LocalBlobStore


def test_atomic_deduplication_and_integrity(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    with ThreadPoolExecutor(max_workers=8) as pool:
        digests = list(pool.map(lambda _: store.put_json({"immutable": [1, 2, 3]}), range(32)))
    assert len(set(digests)) == 1
    assert store.get_json(digests[0]) == {"immutable": [1, 2, 3]}
    store._path(digests[0]).write_bytes(b"corrupt")
    with pytest.raises(OSError):
        store.get_json(digests[0])
    with pytest.raises(OSError):
        store.put_json({"immutable": [1, 2, 3]})


@pytest.mark.parametrize("key", ["../private", "a" * 65, "A" * 64, "file:///secrets"])
def test_no_paths_from_client(tmp_path, key):
    with pytest.raises(ValueError):
        LocalBlobStore(str(tmp_path)).get_json(key)

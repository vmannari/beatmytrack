"""Cursor rejection and failed cache flights exercise the public review regressions."""
import base64
from concurrent.futures import Future, ThreadPoolExecutor
from threading import Event

import pytest
from fastapi import HTTPException
from test_domains import domain as domain_fixture
from test_domains import public_course

from bmt_backend import board_cache
from bmt_backend.cursors import decode_cursor, encode_cursor

domain = domain_fixture


@pytest.mark.parametrize("body", [
    b'{"ticks":1,"ticks":2}', b'{"player":"\\ud800"}', b'{"\\ud800":1}',
    b'{"ticks":1e400}', b'{"ticks":NaN}', b'{"ticks":100000000000000000000000}',
    b'{"scope":[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[1]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]}',
])
def test_cursor_rejects_invalid_json_domains(body):
    cursor = base64.urlsafe_b64encode(body).decode().rstrip("=")
    with pytest.raises(HTTPException) as failure:
        decode_cursor(cursor)
    assert failure.value.status_code == 422
    assert failure.value.detail == "INVALID_CURSOR"


def test_malformed_cursors_are_rejected_before_database_binding(domain):
    _, board = public_course(domain)
    for packet in ({"ticks": 10**90, "player": "x"}, {"ticks": 1, "player": "\ud800"},
                   {"ticks": -1, "player": "x" * 36}, {"ticks": 216001, "player": "x" * 36}):
        response = domain.client.get(f"/v1/boards/{board}", params={"cursor": encode_cursor(packet)})
        assert response.status_code == 422, response.text
    response = domain.client.get("/v1/tracks", params={"cursor": encode_cursor({"snapshot": 10**90})})
    assert response.status_code == 422, response.text


def test_failed_cache_flight_is_shared_and_a_later_call_can_retry(monkeypatch):
    waiting, started, release = Event(), Event(), Event()

    class ObservedFuture(Future):
        def result(self, timeout=None):
            waiting.set()
            return super().result(timeout)

    class Bind:
        pass

    class Session:
        def get_bind(self):
            return bind

    bind, session = Bind(), Session()
    calls = []

    def compute():
        calls.append(1)
        started.set()
        assert release.wait(5)
        raise RuntimeError("dependency unavailable")

    monkeypatch.setattr(board_cache, "Future", ObservedFuture)
    with ThreadPoolExecutor(max_workers=2) as workers:
        owner = workers.submit(board_cache.cached, session, "snapshot", compute)
        assert started.wait(5)
        waiter = workers.submit(board_cache.cached, session, "snapshot", compute)
        try:
            assert waiting.wait(5)
        finally:
            release.set()
        for result in (owner, waiter):
            with pytest.raises(RuntimeError, match="dependency unavailable"):
                result.result(timeout=5)
    assert len(calls) == 1
    assert board_cache.cached(session, "snapshot", lambda: b"recovered") == b"recovered"
    assert board_cache.cached(session, "snapshot", compute) == b"recovered"

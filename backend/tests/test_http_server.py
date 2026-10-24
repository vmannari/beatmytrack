"""Real TCP tests of admission before ASGI; all servers are owned loopback fixtures."""
import http.client
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest


def application():
    import asyncio

    from fastapi import Request

    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.migrate import upgrade
    app = create_app(Settings(database_url="sqlite://", object_dir=os.environ["BMT_HTTP_TEST_OBJECTS"],
                              google_client_ids=("fixture",)))
    upgrade(app.state.engine)

    @app.get("/review/active")
    async def active():
        await asyncio.sleep(2.3)
        return {"active": True}

    @app.post("/review/echo")
    @app.post("/review/upload/versions")
    async def echo(request: Request):
        return await request.json()

    return app


class Peer:
    def __init__(self, port):
        self.port = port

    def connect(self):
        return socket.create_connection(("127.0.0.1", self.port), timeout=4)

    def request(self, path="/healthz", *, method="GET", body=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        try:
            conn.request(method, path, body, {"Connection": "close", "Content-Type": "application/json"})
            response = conn.getresponse()
            return response.status, response.read()
        finally:
            conn.close()


@pytest.fixture(scope="module", params=["bounded"])
def server(tmp_path_factory, request):
    folder = tmp_path_factory.mktemp("http-guard")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    backend = Path(__file__).resolve().parents[1]
    env = {k: v for k, v in os.environ.items() if not k.startswith("BMT_")}
    env["PYTHONPATH"] = str(backend) + os.pathsep + str(backend / "tests")
    env["BMT_HTTP_TEST_OBJECTS"] = str(folder / "objects")
    command = [sys.executable, "-m", "bmt_backend.http_server" if request.param == "bounded" else "uvicorn",
               "test_http_server:application", "--factory", "--host", "127.0.0.1", "--port", str(port),
               "--limit-concurrency", "24", "--timeout-keep-alive", "5", "--no-proxy-headers", "--no-access-log"]
    peer = Peer(port)
    with (folder / "server.log").open("wb") as output:
        process = subprocess.Popen(command, env=env, stdout=output, stderr=output)
        try:
            for _ in range(150):
                try:
                    if peer.request()[0] == 200:
                        break
                except (OSError, http.client.HTTPException):
                    pass
                assert process.poll() is None, (folder / "server.log").read_text(errors="replace")
                time.sleep(.1)
            else:
                pytest.fail("Owned HTTP fixture did not start")
            yield peer
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)


@pytest.mark.parametrize("server", ["original", "bounded"], indirect=True)
def test_incomplete_heads_cannot_deny_health_or_normal_auth(server, request):
    held = []
    try:
        for _ in range(23):
            connection = server.connect()
            connection.sendall(b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nX-Partial: ")
            held.append(connection)
            time.sleep(.01)
        expected = 503 if request.node.callspec.params["server"] == "original" else 200
        assert [server.request()[0] for _ in range(3)] == [expected] * 3
        auth = server.request("/v1/auth/google/challenge", method="POST", body="{}")[0]
        assert auth == (503 if expected == 503 else 201)
        time.sleep(2.2)
        assert server.request()[0] == expected
        if expected == 200:
            for connection in held:
                assert connection.recv(1024) == b""
    finally:
        for connection in held:
            connection.close()
    time.sleep(.1)
    assert server.request()[0] == 200


def test_no_byte_connections_cannot_deny_an_arriving_complete_request(server):
    held = [server.connect() for _ in range(23)]
    try:
        assert server.request()[0] == 200
        time.sleep(2.2)
        assert all(connection.recv(1024) == b"" for connection in held)
    finally:
        for connection in held:
            connection.close()


def test_header_deadline_is_not_renewed_by_progress(server):
    with server.connect() as connection:
        connection.sendall(b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nX-Partial: ")
        started = time.monotonic()
        for _ in range(3):
            time.sleep(.55)
            connection.sendall(b"x")
        assert connection.recv(1024) == b""
        assert time.monotonic() - started < 2.8
    assert server.request()[0] == 200


def test_active_response_survives_header_deadline(server):
    assert server.request("/review/active")[0] == 200
    assert server.request("/review/echo", method="POST", body='{"value":"unchanged"}')[1] == b'{"value":"unchanged"}'


def test_active_upload_keeps_its_existing_body_allowance(server):
    with server.connect() as connection:
        body = b'{"value":"' + b'x' * 100 + b'"}'
        head = (b"POST /review/upload/versions HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n"
                b"Content-Type: application/json\r\nContent-Length: " + str(len(body)).encode() + b"\r\n\r\n")
        connection.sendall(head + body[:20])
        time.sleep(2.3)
        connection.sendall(body[20:])
        response = http.client.HTTPResponse(connection)
        response.begin()
        assert response.status == 200
        assert response.read() == body


def test_idle_keepalive_connections_yield_to_new_work(server):
    peers = []
    try:
        for _ in range(23):
            connection = http.client.HTTPConnection("127.0.0.1", server.port, timeout=4)
            connection.request("GET", "/healthz")
            reply = connection.getresponse()
            assert reply.status == 200
            reply.read()
            peers.append(connection)
        assert server.request()[0] == 200
    finally:
        for connection in peers:
            connection.close()


def test_partial_second_request_has_an_absolute_deadline(server):
    connection = http.client.HTTPConnection("127.0.0.1", server.port, timeout=4)
    try:
        connection.request("GET", "/healthz")
        reply = connection.getresponse()
        assert reply.status == 200
        reply.read()
        connection.sock.sendall(b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nX-Partial: ")
        assert connection.sock.recv(1024) == b""
        assert server.request()[0] == 200
    finally:
        connection.close()


def test_pipelined_partial_head_expires_after_active_response(server):
    with server.connect() as connection:
        connection.sendall(b"GET /review/active HTTP/1.1\r\nHost: localhost\r\n\r\n"
                           b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nX-Partial: ")
        received = bytearray()
        while True:
            part = connection.recv(1024)
            if not part:
                break
            received.extend(part)
        assert received.startswith(b"HTTP/1.1 200")
        assert b'{"active":true}' in received
        assert received.count(b"HTTP/1.1") == 1


def test_oversized_partial_headers_and_malformed_heads_close(server):
    for body in (b"GET /healthz HTTP/1.1\r\nHost: localhost\r\nX: " + b"x" * 17000,
                 b"GET /healthz HTTP/1.1\r\nBad Header\r\n\r\n"):
        with server.connect() as connection:
            connection.sendall(body)
            received = bytearray()
            while True:
                part = connection.recv(4096)
                if not part:
                    break
                received.extend(part)
            assert received.startswith(b"HTTP/1.1 400")
    assert server.request()[0] == 200

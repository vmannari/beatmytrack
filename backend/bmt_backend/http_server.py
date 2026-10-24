"""Bound HTTP connections before ASGI, using the locked Uvicorn/h11 parser."""
import argparse
from collections import OrderedDict

import h11
import uvicorn
from uvicorn.protocols.http.h11_impl import H11Protocol

HEADER_SECONDS = 2.0
IDLE_CONNECTIONS = 8
HEADER_BYTES = 16384


class BoundedH11Protocol(H11Protocol):
    """Keep idle/incomplete heads out of the application's connection reserve.

    The oldest inactive socket yields to an arriving connection. Active bodies
    and responses are never evicted. Header deadlines are absolute, including
    the next request on a persistent connection; dripping bytes cannot renew one.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if not hasattr(self.server_state, "bmt_inactive_connections"):
            self.server_state.bmt_inactive_connections = OrderedDict()
        self.inactive = self.server_state.bmt_inactive_connections
        self.header_timer = None
        self.closed_by_guard = False

    def _forget(self):
        self.inactive.pop(self, None)
        if self.header_timer is not None:
            self.header_timer.cancel()
            self.header_timer = None

    def _expire(self):
        self._forget()
        self.closed_by_guard = True
        # Release the allowance synchronously, before the next complete request
        # reaches Uvicorn's admission check. connection_lost remains idempotent.
        self.connections.discard(self)
        self.transport.close()

    def _wait_for_head(self, *, deadline):
        if self.transport.is_closing():
            self._forget()
            return
        self.inactive.setdefault(self, None)
        if deadline and self.header_timer is None:
            self.header_timer = self.loop.call_later(HEADER_SECONDS, self._expire)
        while len(self.inactive) > IDLE_CONNECTIONS:
            next(iter(self.inactive))._expire()

    def connection_made(self, transport):
        super().connection_made(transport)
        self._wait_for_head(deadline=True)

    def data_received(self, data):
        if self.closed_by_guard or self.transport.is_closing():
            return
        if self.conn.their_state is h11.IDLE:
            self._wait_for_head(deadline=True)
        super().data_received(data)

    def handle_events(self):
        super().handle_events()
        if self.transport.is_closing():
            self._forget()
        elif self.conn.their_state is h11.IDLE:
            # A pipelined partial head may already be buffered when the previous
            # response completes. Empty keep-alive uses Uvicorn's existing timer.
            self._wait_for_head(deadline=bool(self.conn.trailing_data[0]))
        else:
            self._forget()

    def on_response_complete(self):
        super().on_response_complete()
        if not self.transport.is_closing() and self.conn.their_state is h11.IDLE:
            self._wait_for_head(deadline=bool(self.conn.trailing_data[0]))

    def connection_lost(self, exc):
        self._forget()
        super().connection_lost(exc)

    def shutdown(self):
        self._forget()
        super().shutdown()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", nargs="?", default="bmt_backend.app:create_app")
    parser.add_argument("--factory", action="store_true", default=True)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--limit-concurrency", type=int, default=24)
    parser.add_argument("--timeout-keep-alive", type=int, default=5)
    parser.add_argument("--no-proxy-headers", action="store_true")
    parser.add_argument("--no-access-log", action="store_true")
    args = parser.parse_args(argv)
    if args.limit_concurrency < 16 or not 1 <= args.timeout_keep_alive <= 5:
        parser.error("Connection admission needs at least 16 slots and keep-alive of 1–5 seconds")
    uvicorn.run(args.app, factory=args.factory, host=args.host, port=args.port,
                http=BoundedH11Protocol, ws="none", loop="asyncio",
                proxy_headers=False, access_log=False,
                limit_concurrency=args.limit_concurrency,
                timeout_keep_alive=args.timeout_keep_alive,
                h11_max_incomplete_event_size=HEADER_BYTES)


if __name__ == "__main__":
    main()

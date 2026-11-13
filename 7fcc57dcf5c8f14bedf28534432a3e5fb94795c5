# Backend IPv4 fallback — 3 November 2026

The configured Cloud Run backend was reachable from this Windows PC over IPv4,
but IPv6 connections timed out. Godot selected an IPv6 address and returned
`HTTPRequest.RESULT_TIMEOUT` (13), HTTP 0. An isolated IPv4 Godot connection with
the original TLS hostname returned HTTP 200. Windows curl confirmed IPv6 timeout
and IPv4 HTTP 200 independently.

## Change

`game/backend/ipv4_fallback.gd` asynchronously resolves HTTPS backend addresses.
For dual-stack hosts it gives the IPv6 TCP connection 350 ms to connect. If it
cannot connect, HTTPRequest uses a resolved IPv4 address with the original DNS
name for TLS certificate validation/SNI and the original HTTP Host authority.
The port and base path remain intact. HTTP is sent only once; no potentially
delivered writes are replayed. Normal redirects, payload limits, timeouts,
compression, authorization and idempotency headers remain in the existing client.

Routes expire after 60 seconds so IPv6 can recover. At most eight routes are
cached. DNS preparation has a two-second bound; IPv4-only, IPv6-only, literal
addresses and local HTTP retain their ordinary transport. Cancellation and
account/origin changes during preparation prevent HTTP submission. Reused
HTTPRequest nodes reset their TLS options before every request.

## Verification

All unattended engine commands used `python scripts/run_no_crash_dialog.py --`.
Pinned engine: `C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe`.

Focused command, with a workspace absolute path for `--log-file`:

```text
godot --headless --path game --log-file <workspace>/build/ipv4-fallback-live.log --script tests/test_ipv4_fallback.gd -- --live
```

Final **21 checks, zero failures**: healthy/failed IPv6, family-only hosts,
literal/loopback hosts, DNS failure, route caching/expiry, port/base-path/Host
preservation, cancellation and account fencing, two actual backend-client public
bootstrap reads (HTTP 200), and rejection of an intentionally wrong TLS hostname.
The negative TLS test deliberately emits a handshake error; it is an expected
asserted rejection, not a successful connection. Live mode requires this PC's
reproduced IPv6 failure; ordinary focused mode is deterministic and offline.

Existing native adapter integration also passed:

```powershell
$env:PYTHONPATH = 'backend'
$env:BMT_GODOT_BIN = 'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe'
python scripts/run_no_crash_dialog.py -- .tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -k godot_http_adapter --basetemp build/ipv4-fallback-pytest -q
```

**One test passed, 69 deselected**, including 13 native checks for authentication,
refresh, unchanged mutation idempotency/body, conditional reads, logout and
credential-safe redirect refusal against an isolated loopback HTTP server.

Initial findings retained: null TLS options were rejected by Godot during the
first successful live run; corrected to `TLSOptions.client()` before final
validation. The system Python lacks pytest; the existing backend virtualenv was
used. Direct sandbox runs of `test_backend_exception_recovery.gd` and
`test_backend_reuse.gd` hit mock-response/storage failures and script errors and
were stopped; they are not passes. Sandbox certificate-store access and an
initial relative log path also produced diagnostics. No claim is made that those
broader fixtures now pass.

No backend deployment, authenticated live request, player-save edit, device test,
APK build or owner-process restart occurred. Reload the game to use the change.
Concurrent workspace changes were preserved. Raw task logs are under `build/`.

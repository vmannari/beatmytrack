"""Current authorization stays in routes; immutable bytes need not be redownloaded."""
import hashlib
import re

from fastapi import HTTPException
from fastapi.responses import JSONResponse, Response

from .storage import canonical_json


def recording_response(request, run_id, content_hash, player_id, *, metadata=False, expected_run_id="", encoding="json"):
    if encoding not in ("json", "packed"):
        raise HTTPException(422, "UNSUPPORTED_GHOST_ENCODING")
    if not re.fullmatch(r"[0-9a-f]{64}", content_hash):
        raise OSError("Invalid recording digest")
    if expected_run_id and expected_run_id != run_id:
        raise HTTPException(409, "GHOST_TARGET_CHANGED")
    value = {"run_id": run_id, "content_hash": content_hash, "player_id": player_id}
    tag = '"' + hashlib.sha256(canonical_json(value)).hexdigest() + ("-metadata" if metadata else "-"+encoding) + '"'
    headers = {"ETag": tag, "Cache-Control": "private, no-cache, must-revalidate", "Vary": "Authorization, Accept-Encoding"}
    if request.headers.get("if-none-match") == tag:
        return Response(status_code=304, headers=headers)
    if metadata:
        return JSONResponse(value, headers=headers)
    def prepare():
        recording = request.app.state.blobs.get_json(content_hash)
        if encoding == "packed":
            from .ghost_wire import compact
            recording = compact(recording)
        return canonical_json({**value, "recording": recording})
    cache = getattr(request.app.state, "immutable_payloads", None)
    body = cache.get(("ghost", run_id, content_hash, encoding), prepare) if cache else prepare()
    return Response(body, media_type="application/json", headers=headers)

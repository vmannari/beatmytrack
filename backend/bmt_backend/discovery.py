"""Small update-required responses for retired discovery clients."""

from fastapi import APIRouter, HTTPException

from .middleware import ParsedJSONRoute

router = APIRouter(route_class=ParsedJSONRoute,tags=["retired discovery"])

@router.post("/discovery/tracks")
def discover():
    raise HTTPException(426, "DISCOVERY_CLIENT_UPDATE_REQUIRED")


@router.post("/discovery/random")
def choose_random():
    raise HTTPException(426, "DISCOVERY_CLIENT_UPDATE_REQUIRED")

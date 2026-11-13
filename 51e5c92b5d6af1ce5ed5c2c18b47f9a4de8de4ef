"""Named, explicitly allowlisted staff identities independent of game accounts."""

import base64
import hashlib

from fastapi import HTTPException
from sqlalchemy import event

from .admin_models import AdminAudit
from .studio_platform_models import StudioStaff
from .studio_settings import mapping
from .track_models import now


class StaffRole(str):
    def __new__(cls, role, actor, name):
        value = super().__new__(cls, role)
        value.actor_id, value.display_name = actor, name
        return value


def actor(role):
    return getattr(role, "actor_id", str(role))


def staff_identity(subject):
    return "s_" + base64.urlsafe_b64encode(
        hashlib.sha256(("https://accounts.google.com/" + subject).encode()).digest()
    ).decode()[:22]


def named_access(request, supplied):
    settings = request.app.state.settings
    if not settings.studio_staff_audiences or not supplied:
        raise HTTPException(401, "ADMIN_AUTH_REQUIRED")
    claims = request.app.state.staff_identity_verifier.verify(supplied)
    entry = mapping(settings.studio_staff_subjects).get(claims.get("sub"))
    if not entry:
        raise HTTPException(403, "STAFF_NOT_AUTHORISED")
    amr = claims.get("amr")
    if (settings.studio_staff_require_mfa or settings.environment == "production") and (
        not isinstance(amr, list)
        or any(not isinstance(v, str) for v in amr)
        or not set(amr).intersection({"mfa", "otp"})
    ):
        raise HTTPException(403, "STAFF_MFA_CLAIM_REQUIRED")
    identity = staff_identity(claims["sub"])
    with request.app.state.session_factory() as db:
        row = db.get(StudioStaff, identity)
        if row is not None and not row.enabled:
            raise HTTPException(403, "STAFF_ACCESS_DISABLED")
        if row is None:
            db.add(StudioStaff(id=identity, display_name=entry["name"], role=entry["role"]))
        elif row.last_seen_at < now() - 60 or row.role != entry["role"] or row.display_name != entry["name"]:
            row.last_seen_at, row.role, row.display_name = now(), entry["role"], entry["name"]
        db.commit()
    return StaffRole(entry["role"], identity, entry["name"])


@event.listens_for(AdminAudit, "before_insert")
def named_audit(_mapper, _connection, target):
    target.actor = actor(target.actor)

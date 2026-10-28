"""Usage configuration validation without cloud SDK/network imports."""
import json
import re
from uuid import UUID

RESOURCE_KINDS = ("services", "workerPools", "instances", "jobs")
NAME = r"[a-z][a-z0-9-]{0,62}"


def inventory(settings):
    return json.loads(settings.studio_usage_resources or "{}")


def validate_settings(settings):
    if settings.studio_usage_project and not re.fullmatch(r"[a-z][a-z0-9-]{4,61}[a-z0-9]", settings.studio_usage_project):
        raise ValueError("Invalid usage project")
    if not re.fullmatch(r"[a-z]+-[a-z]+[0-9]+", settings.studio_usage_region):
        raise ValueError("Invalid usage region")
    try:
        resources = inventory(settings)
        valid = isinstance(resources, dict) and set(resources) <= set(RESOURCE_KINDS)
        valid = valid and sum(len(v) for v in resources.values()) <= 12
        valid = valid and all(isinstance(v, list) and 0 < len(v) == len(set(v))
            and all(isinstance(n, str) and re.fullmatch(NAME, n) for n in v) for v in resources.values())
        if not valid:
            raise ValueError()
    except (ValueError, TypeError):
        raise ValueError("Usage resources require up to 12 explicit Cloud Run/SQL names") from None
    if settings.studio_usage_player_id:
        try:
            UUID(settings.studio_usage_player_id)
        except ValueError:
            raise ValueError("Usage player binding requires a stable player UUID") from None
    table = settings.studio_usage_billing_table
    if table and not re.fullmatch(r"[a-z][a-z0-9-]{4,62}\.[A-Za-z_][A-Za-z_0-9]{0,100}\.[A-Za-z_][A-Za-z_0-9-]{0,180}", table):
        raise ValueError("Usage billing requires one explicit detailed-export table")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]{0,40}", settings.studio_usage_billing_location):
        raise ValueError("Invalid usage billing location")


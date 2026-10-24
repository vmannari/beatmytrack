"""Registered noncanonical settings and bounded, deterministic audience resolution."""
import re
from copy import deepcopy
from uuid import UUID

from fastapi import HTTPException

from .track_models import digest

PRODUCTS = ["creator_slot_1", "creator_slots_5", "creator_slots_10", "ad_free_month", "ad_free_forever"]
CAPABILITIES = {"ad_policy_v1", "menu_policy_v1"}
REGISTRY = {}


def register(key, label, default, kind, *, category="Advertising", minimum=None, maximum=None,
             values=None, capability="ad_policy_v1", boundary="race_result", experiment=True):
    REGISTRY[key] = {"label": label, "default": default, "kind": kind, "category": category,
        "minimum": minimum, "maximum": maximum, "values": values, "capability": capability,
        "boundary": boundary, "experiment": experiment}


register("ads.permitted", "All advertising permitted", False, "boolean", experiment=False)
register("ads.interstitial_enabled", "Automatic ads enabled", False, "boolean")
register("ads.trigger", "Become due when", "either", "enum", values=["either", "both"])
register("ads.races", "Completed races threshold", 3, "integer", minimum=1, maximum=100)
register("ads.active_seconds", "Active time threshold (seconds)", 600, "integer", minimum=60, maximum=7200)
register("ads.first_delay_seconds", "First-ad delay (active seconds)", 0, "integer", minimum=0, maximum=7200)
register("ads.min_races", "Minimum races between ads", 0, "integer", minimum=0, maximum=100)
register("ads.min_seconds", "Minimum active seconds between ads", 0, "integer", minimum=0, maximum=7200)
register("ads.rewarded_cooldown_seconds", "Wait after rewarded ad (active seconds)", 0, "integer", minimum=0, maximum=7200)
register("ads.session_cap", "Maximum automatic ads per session", None, "optional_integer", minimum=1, maximum=100)
register("ads.rewarded_resume_enabled", "Rewarded Resume offered", True, "boolean")
register("features.challenge_creation", "New challenge creation available", True, "boolean", category="Features",
    capability="menu_policy_v1", boundary="menu_entry")
register("features.rivalry_entry", "New Weekly Rivalry entry available", True, "boolean", category="Features",
    capability="menu_policy_v1", boundary="menu_entry")
register("notice.message", "Menu notice", "", "text", maximum=256, category="Messaging",
    capability="menu_policy_v1", boundary="menu_entry")
register("notice.expires_at", "Notice expiry (UTC Unix seconds, 0 for none)", 0, "integer", minimum=0,
    maximum=4102444800, category="Messaging", capability="menu_policy_v1", boundary="menu_entry")
register("store_order", "Store offer order", ["ad_free_forever", "ad_free_month", *PRODUCTS[:3]], "products", category="Store",
    capability="menu_policy_v1", boundary="store_entry")
DEFAULTS = {key: deepcopy(meta["default"]) for key, meta in REGISTRY.items()}


def fail(code, **detail):
    raise HTTPException(422, {"code": code, **detail})


def validate_settings(settings, *, partial=False, experimental=False):
    if not isinstance(settings, dict) or not set(settings) <= set(REGISTRY):
        fail("UNREGISTERED_SETTINGS")
    if not partial and set(settings) != set(REGISTRY):
        fail("INCOMPLETE_POLICY")
    for key, value in settings.items():
        meta = REGISTRY[key]
        if experimental and not meta["experiment"]:
            fail("SETTING_NOT_EXPERIMENT_ELIGIBLE", field=key)
        kind = meta["kind"]
        if kind == "boolean":
            valid = type(value) is bool
        elif kind == "enum":
            valid = isinstance(value, str) and value in meta["values"]
        elif kind == "text":
            valid = (isinstance(value, str) and len(value) <= meta["maximum"] and
                all(ord(c) >= 32 or c == "\n" for c in value))
        elif kind == "products":
            valid = (isinstance(value, list) and len(value) == len(PRODUCTS) and
                all(isinstance(v, str) for v in value) and set(value) == set(PRODUCTS))
        elif kind == "optional_integer" and value is None:
            valid = True
        else:
            valid = kind in ("integer", "optional_integer") and type(value) is int and meta["minimum"] <= value <= meta["maximum"]
        if not valid:
            fail("INVALID_SETTING_VALUE", field=key)
    return deepcopy(settings)


def validate_conditions(conditions):
    allowed = {"platforms", "builds", "capabilities", "authenticated", "ad_free", "player_ids"}
    if not isinstance(conditions, dict) or not set(conditions) <= allowed:
        fail("INVALID_AUDIENCE_CONDITIONS")
    for key, value in conditions.items():
        if key in ("authenticated", "ad_free"):
            if type(value) is not bool:
                fail("INVALID_AUDIENCE_CONDITION", field=key)
            continue
        if not isinstance(value, list) or not 1 <= len(value) <= 100 or any(not isinstance(v, str) for v in value):
            fail("INVALID_AUDIENCE_CONDITION", field=key)
        if key == "platforms" and not set(value) <= {"android", "windows", "linux", "ios"}:
            fail("INVALID_AUDIENCE_PLATFORM")
        if key == "capabilities" and not set(value) <= CAPABILITIES:
            fail("INVALID_AUDIENCE_CAPABILITY")
        if key == "builds" and any(not re.fullmatch(r"[A-Za-z0-9._:-]{1,80}", v) for v in value):
            fail("INVALID_AUDIENCE_BUILD")
        if key == "player_ids":
            try:
                for item in value:
                    UUID(item)
            except ValueError:
                fail("INVALID_INTERNAL_PLAYER_ID")
    return deepcopy(conditions)


def overlap(a, b):
    for key in ("authenticated", "ad_free"):
        if key in a and key in b and a[key] != b[key]:
            return False
    for key in ("platforms", "builds", "player_ids"):
        if key in a and key in b and not set(a[key]) & set(b[key]):
            return False
    return True


def validate_audiences(items):
    if not isinstance(items, list) or len(items) > 16:
        fail("AUDIENCE_LIMIT_16")
    names = set()
    for item in items:
        if not isinstance(item, dict) or set(item) != {"name", "priority", "conditions", "settings"}:
            fail("INVALID_AUDIENCE")
        if not isinstance(item["name"], str) or not 1 <= len(item["name"]) <= 80 or item["name"] in names:
            fail("INVALID_AUDIENCE_NAME")
        names.add(item["name"])
        if type(item["priority"]) is not int or not 0 <= item["priority"] <= 100:
            fail("INVALID_AUDIENCE_PRIORITY")
        validate_conditions(item["conditions"])
        validate_settings(item["settings"], partial=True)
    for i, a in enumerate(items):
        for b in items[i + 1:]:
            if a["priority"] == b["priority"] and set(a["settings"]) & set(b["settings"]) and overlap(a["conditions"], b["conditions"]):
                fail("AMBIGUOUS_AUDIENCE_OVERRIDE", audiences=[a["name"], b["name"]])
    return deepcopy(items)


def matches(conditions, context):
    for key, value in conditions.items():
        if key == "capabilities":
            if not set(value) <= set(context.get(key, [])):
                return False
        elif key in ("authenticated", "ad_free"):
            if context.get(key) is not value:
                return False
        else:
            field = {"platforms": "platform", "builds": "build_id", "player_ids": "player_id"}[key]
            if context.get(field) not in value:
                return False
    return True


def bucket(subject, salt):
    return int(digest({"subject": subject, "salt": salt})[:16], 16) % 10000


def resolve(policy, audiences, context):
    result, sources = deepcopy(policy), {key: "baseline" for key in policy}
    for audience in sorted(audiences, key=lambda a: (a["priority"], a["name"])):
        if matches(audience["conditions"], context):
            result.update(deepcopy(audience["settings"]))
            sources.update({key: audience["name"] for key in audience["settings"]})
    return result, sources


def protect(policy, context, emergency, at):
    result, restrictions = deepcopy(policy), []
    for key, meta in REGISTRY.items():
        if meta["capability"] not in context.get("capabilities", []):
            result[key] = deepcopy(DEFAULTS[key])
            if meta["capability"] == "ad_policy_v1":
                result["ads.permitted"] = False
    for key in ("ads.permitted", "ads.interstitial_enabled", "ads.rewarded_resume_enabled"):
        if emergency.get(key) is False:
            result[key] = False
            restrictions.append("emergency:" + key)
    if context.get("ad_free"):
        result["ads.interstitial_enabled"] = False
        restrictions.append("ad_free_entitlement")
    if result["notice.expires_at"] and result["notice.expires_at"] <= at:
        result["notice.message"] = ""
    return result, restrictions

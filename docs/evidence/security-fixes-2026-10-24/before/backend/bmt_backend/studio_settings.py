"""Fail-closed settings for independently configured Studio integrations."""

import json
import re
from urllib.parse import urlsplit


def mapping(value):
    try:
        result = json.loads(value) if value else {}
    except (ValueError, TypeError):
        raise ValueError("Invalid Studio integration mapping") from None
    if not isinstance(result, dict) or len(result) > 100:
        raise ValueError("Invalid Studio integration mapping")
    return result


def validate_studio_settings(settings):
    staff = mapping(settings.studio_staff_subjects)
    for subject, record in staff.items():
        if (
            not isinstance(subject, str)
            or not 1 <= len(subject) <= 255
            or not isinstance(record, dict)
            or set(record) != {"name", "role"}
            or record["role"] not in ("owner", "analyst")
            or not isinstance(record["name"], str)
            or not 1 <= len(record["name"]) <= 100
        ):
            raise ValueError("Invalid named staff configuration")
    if bool(staff) != bool(settings.studio_staff_audiences):
        raise ValueError("Staff sign-in requires both explicit audiences and authorised subjects")
    if set(settings.studio_staff_audiences).intersection(
        (*settings.google_client_ids, settings.google_web_client_id)
    ):
        raise ValueError("Staff audiences must be separate from game sign-in audiences")
    for source, token in mapping(settings.studio_monitor_source_tokens).items():
        if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", source) or not isinstance(token, str) or len(token) < 32:
            raise ValueError("Monitor sources require stable names and separate strong credentials")
    if not set(settings.studio_monitor_external_notifiers) <= set(
        mapping(settings.studio_monitor_source_tokens)
    ):
        raise ValueError("External notification sources must have dedicated configured credentials")
    if not 10 <= settings.studio_monitor_poll_seconds <= 300:
        raise ValueError("Monitor poll interval must be10-300 seconds")
    if settings.studio_monitor_webhook_url:
        url = urlsplit(settings.studio_monitor_webhook_url)
        if (
            url.scheme != "https"
            or not url.hostname
            or url.username
            or url.password
            or url.fragment
            or len(settings.studio_monitor_webhook_key) < 32
        ):
            raise ValueError("Incident delivery requires an explicit HTTPS destination and signing key")
    if settings.studio_play_package and not re.fullmatch(
        r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+", settings.studio_play_package
    ):
        raise ValueError("Invalid Play package")
    if settings.studio_admob_account and not re.fullmatch(
        r"accounts/pub-[0-9]{8,24}", settings.studio_admob_account
    ):
        raise ValueError("Invalid AdMob account")

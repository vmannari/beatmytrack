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
    from .studio_usage_settings import validate_settings as validate_usage
    validate_usage(settings)
    if settings.studio_analysis_mode not in ("replica", "shared_limited"):
        raise ValueError("Invalid Studio analysis mode")
    if settings.studio_analysis_mode == "shared_limited":
        from sqlalchemy.engine import make_url
        if settings.workload_role != "admin" or not settings.studio_analysis_database_url:
            raise ValueError("Limited shared reporting requires the private admin service and a separate reader URL")
        reader = make_url(settings.studio_analysis_database_url)
        primary = make_url(settings.database_url)
        if (reader.drivername != "postgresql+psycopg" or reader.username != "bmt_studio_report"
                or reader.username == primary.username):
            raise ValueError("Limited shared reporting requires the dedicated bmt_studio_report credential")
    identity = (settings.studio_identity_project, settings.studio_identity_tenant,
                settings.studio_identity_api_key, settings.studio_identity_auth_domain)
    if any(identity):
        if not all(identity) or not re.fullmatch(r"[a-z][a-z0-9-]{4,61}[a-z0-9]", identity[0]):
            raise ValueError("Studio Identity Platform requires project, tenant, API key and auth domain")
        if not re.fullmatch(r"[A-Za-z0-9-]{1,128}", identity[1]):
            raise ValueError("Invalid Studio identity tenant")
        if identity[3] != identity[0] + ".firebaseapp.com":
            raise ValueError("Studio auth domain must belong to the configured identity project")
        if settings.studio_staff_audiences != (identity[0],):
            raise ValueError("Identity Platform staff audience must be its dedicated project audience")
        if settings.workload_role != "admin":
            raise ValueError("Studio identity configuration belongs only to the private admin service")
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

"""Registered optional observations projected in the existing owned player batch."""
import re

from .game_config_models import GameConfigDelivery
from .studio_platform_models import StudioAssignment, StudioExperiment

NAMES = {"config_applied", "config_rejected", "experiment_exposed", "ad_policy_decision"}
COMMON = {"config_generation", "config_resolution", "experiment_id", "variant", "experiment_revision", "config_group"}
FIELDS = {"config_applied": COMMON, "config_rejected": COMMON,
    "experiment_exposed": COMMON, "ad_policy_decision": COMMON | {"ad_outcome"}}


def validate(name, value):
    from .telemetry import integer, uuid_value
    if not isinstance(value, dict) or not set(value) <= FIELDS[name] or not {"config_generation", "config_resolution"} <= set(value):
        raise ValueError("INVALID_CONFIG_OBSERVATION")
    result = {}
    for key, item in value.items():
        if key in ("config_generation", "experiment_revision"):
            item = integer(item, high=2147483647)
        elif key == "config_resolution":
            if not isinstance(item, str) or not re.fullmatch(r"[a-f0-9]{64}", item):
                raise ValueError("INVALID_CONFIG_RESOLUTION")
        elif key == "experiment_id":
            item = uuid_value(item)
        elif key == "variant":
            if not isinstance(item, str) or not re.fullmatch(r"[a-z][a-z0-9_-]{0,23}", item):
                raise ValueError("INVALID_CONFIG_VARIANT")
        elif key == "ad_outcome" and item not in ("shown", "suppressed", "unavailable", "error"):
            raise ValueError("INVALID_AD_OUTCOME")
        elif key == "config_group" and item not in ("ads", "menu", "store"):
            raise ValueError("INVALID_CONFIG_GROUP")
        result[key] = item
    reference = {"experiment_id", "variant", "experiment_revision"}
    if reference & set(result) and not reference <= set(result):
        raise ValueError("INCOMPLETE_EXPERIMENT_REFERENCE")
    if name == "experiment_exposed" and not reference <= set(result):
        raise ValueError("EXPERIMENT_REFERENCE_REQUIRED")
    if name == "ad_policy_decision" and "ad_outcome" not in result:
        raise ValueError("AD_OUTCOME_REQUIRED")
    return result


def project(session, events):
    for event in events:
        if event.source != "client" or event.name not in NAMES:
            continue
        props = event.properties
        if event.name in ("config_applied", "config_rejected"):
            row = session.get(GameConfigDelivery, event.player_id)
            if row is None:
                row = GameConfigDelivery(player_id=event.player_id, observed_at=0)
                session.add(row)
            if event.occurred_at >= row.observed_at:
                row.generation = props["config_generation"]
                row.status = "applied" if event.name == "config_applied" else "rejected"
                row.observed_at = event.occurred_at
                row.platform, row.build_id = event.platform, event.build_id
                if event.name == "config_applied" and props.get("config_group"):
                    row.applied_groups = {**(row.applied_groups or {}), props["config_group"]:
                        {"generation": row.generation, "resolution": props["config_resolution"], "observed_at": row.observed_at}}
        if "experiment_id" not in props:
            continue
        experiment = session.get(StudioExperiment, props["experiment_id"])
        bound = session.get(StudioAssignment, (props["experiment_id"], event.player_id))
        if (not experiment or not experiment.configuration or not bound or
            (bound.variant, bound.revision) != (props["variant"], props["experiment_revision"]) or
            event.occurred_at < bound.assigned_at or
            (experiment.stopped_at and event.occurred_at > experiment.stopped_at)):
            continue
        if event.name == "experiment_exposed" and bound.exposed_at is None:
            bound.exposed_at, bound.exposure_id = event.occurred_at, event.id
        if event.name == "ad_policy_decision" and bound.exposed_at is not None:
            counts = dict(bound.observed_counters or {})
            counts[props["ad_outcome"]] = counts.get(props["ad_outcome"], 0) + 1
            bound.observed_counters = counts

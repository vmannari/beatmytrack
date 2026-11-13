"""Load only the HTTP routes served by this workload."""
from importlib import import_module

from .workloads import administration_enabled


def mount_routes(app, settings):
    def mount(name, attribute="router", prefix=""):
        module = import_module("." + name, package=__package__)
        app.include_router(getattr(module, attribute), prefix=prefix)

    if administration_enabled(settings):
        for name in ("studio_identity", "admin", "admin_commerce", "admin_purchase_controls", "admin_player_grants",
                     "admin_support", "studio", "studio_analysis", "studio_metrics", "studio_usage", "studio_jobs",
                     "studio_ranking", "studio_incidents", "studio_finance", "studio_experiments", "game_config",
                     "studio_governance", "studio_alarms", "studio_cases", "studio_competitions", "studio_rivalry", "studio_catalogue", "studio_reported_tracks"):
            mount(name)
        mount("publications", "admin_router", "/v1")
    if settings.workload_role != "admin":
        mount("game_config", "public_router")
        mount("studio_experiments", "public_router")
        for name in ("telemetry", "community", "privacy", "privacy_pages", "public_pages", "product_analytics", "quality", "network_health"):
            mount(name)
        mount("news", prefix="/v1")
        mount("race_statistics")
        for name in ("auth", "browser_auth", "tracks", "discovery"):
            mount(name, prefix="/v1")
        mount("discovery_v3")
        mount("track_of_day")
        for name in ("runs", "economy", "achievements", "resumes", "commerce", "publications", "rivalry", "appearance_routes", "challenges"):
            mount(name, prefix="/v1")
        mount("world_ranking")
        mount("challenges", "preview_router")
        mount("track_links")
        mount("test_drivers", prefix="/v1")
        mount("test_population_batch", prefix="/v1")

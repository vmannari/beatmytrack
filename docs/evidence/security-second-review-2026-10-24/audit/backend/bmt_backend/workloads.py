"""The public game process never exposes the administrative service boundary."""


def administration_enabled(settings):
    return settings.workload_role == "admin" or (
        settings.environment != "production" and settings.workload_role == "api"
        and settings.studio_legacy_keys_enabled
    )


def administrative_path(path):
    return any(
        path == prefix or path.startswith(prefix + "/") for prefix in ("/admin", "/v1/admin", "/v1/monitor")
    )

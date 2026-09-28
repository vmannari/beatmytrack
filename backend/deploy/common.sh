#!/bin/sh
# Sourced by backup/restore. Do not enable shell tracing: configuration has secrets.
set -eu
BMT_DEPLOY_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BMT_ENV_FILE=${BMT_ENV_FILE:-$BMT_DEPLOY_DIR/.env}
test -f "$BMT_ENV_FILE" || { echo "Missing deployment env file" >&2; exit 1; }
compose() {
    if [ -n "${BMT_COMPOSE_PROJECT:-}" ]; then
        docker compose --env-file "$BMT_ENV_FILE" -f "$BMT_DEPLOY_DIR/compose.yaml" -p "$BMT_COMPOSE_PROJECT" "$@"
    else
        docker compose --env-file "$BMT_ENV_FILE" -f "$BMT_DEPLOY_DIR/compose.yaml" "$@"
    fi
}

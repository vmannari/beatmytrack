#!/bin/sh
# Restore requires an explicitly named, different, empty Compose project.
# Usage: sh restore.sh /absolute/backup-directory new-project-name
set -eu
. "$(dirname -- "$0")/common.sh"
test "$#" -eq 2 || { echo "Usage: $0 /absolute/backup-directory new-project-name" >&2; exit 2; }
case "$1" in /*) source=$1 ;; *) echo "Use an absolute backup directory" >&2; exit 2 ;; esac
case "$2" in ''|*[!a-z0-9_-]*) echo "Use a lowercase Compose project name" >&2; exit 2 ;; esac
test -f "$source/COMPLETE" || { echo "Backup is incomplete" >&2; exit 1; }
(cd "$source" && sha256sum --check SHA256SUMS)
grep -qx 'format=bmt-backup-v1' "$source/backup.info" || { echo "Unknown backup format" >&2; exit 1; }
original_project=$(sed -n 's/^project=//p' "$source/backup.info")
test "$2" != "$original_project" || { echo "Restore must use a different Compose project" >&2; exit 1; }
BMT_COMPOSE_PROJECT=$2
mkdir "$BMT_DEPLOY_DIR/.backup.lock" || { echo "Another backup/restore is running" >&2; exit 1; }
trap 'rmdir "$BMT_DEPLOY_DIR/.backup.lock"' EXIT
# Refuse to stop or overwrite any pre-existing application deployment.
test -z "$(compose ps -a -q api worker migrate)" || { echo "Target project already contains application containers" >&2; exit 1; }
compose up -d --wait db
table_count=$(compose exec -T db psql -U postgres -d bmt -Atc "SELECT count(*) FROM pg_tables WHERE schemaname='public'")
test "$table_count" = 0 || { echo "Restore requires an empty target database" >&2; exit 1; }
compose run --rm --no-deps -T --entrypoint python api /app/deploy/object_archive.py check-empty
compose run --rm --no-deps -T --entrypoint python api /app/deploy/object_archive.py restore < "$source/objects.tar"
compose exec -T db pg_restore -U postgres -d bmt --role=bmt --exit-on-error --single-transaction --no-owner --no-privileges < "$source/database.dump"
echo "Restored into isolated project $BMT_COMPOSE_PROJECT. API and worker remain stopped. Validate, choose an unused BMT_PORT, then start explicitly."

#!/bin/sh
# Usage: sh backend/deploy/backup.sh /absolute/new/backup-directory
set -eu
. "$(dirname -- "$0")/common.sh"
test "$#" -eq 1 || { echo "Usage: $0 /absolute/new/backup-directory" >&2; exit 2; }
case "$1" in /*) destination=$1 ;; *) echo "Use an absolute backup directory" >&2; exit 2 ;; esac
test ! -e "$destination" || { echo "Backup directory already exists" >&2; exit 1; }
umask 077
mkdir -p "$(dirname -- "$destination")"
mkdir "$destination"
# Exclusive lock is local to this deployment directory; no parallel backups/restores.
mkdir "$BMT_DEPLOY_DIR/.backup.lock" || { echo "Another backup/restore is running" >&2; exit 1; }
running=$(compose ps --status running --services | tr '\n' ' ')
finish() {
    code=$?
    trap - EXIT HUP INT TERM
    for service in api worker; do
        case " $running " in *" $service "*) compose start "$service" >&2 || code=1 ;; esac
    done
    rmdir "$BMT_DEPLOY_DIR/.backup.lock"
    exit "$code"
}
trap finish EXIT
trap 'exit 130' HUP INT TERM
compose stop api worker >&2
compose exec -T db pg_dump -U postgres -d bmt --format=custom --no-owner --no-privileges > "$destination/database.dump"
compose run --rm --no-deps -T --entrypoint python api /app/deploy/object_archive.py archive > "$destination/objects.tar"
database_container=$(compose ps -q db)
project=$(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' "$database_container")
printf 'format=bmt-backup-v1\nproject=%s\ncreated_utc=%s\n' "$project" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$destination/backup.info"
(cd "$destination" && sha256sum database.dump objects.tar backup.info > SHA256SUMS)
printf 'Complete\n' > "$destination/COMPLETE"
echo "Backup completed: $destination"

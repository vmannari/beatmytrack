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
running=""
mode=${BMT_BACKUP_MODE:-online}
guard=""
data_ready=0
finish() {
    code=$?
    trap - EXIT HUP INT TERM
    if test -n "$guard"; then
        compose run --rm --no-deps -T --entrypoint python api -m bmt_backend.backup_guard end --token "$guard" >&2 || code=1
    fi
    if test "$mode" = offline; then
        for service in api worker; do
            case " $running " in *" $service "*) compose start "$service" >&2 || code=1 ;; esac
        done
    fi
    rmdir "$BMT_DEPLOY_DIR/.backup.lock" || code=1
    if test "$code" -eq 0 && test "$data_ready" -eq 1; then
        printf 'Complete\n' > "$destination/COMPLETE" || code=1
        if test "$code" -eq 0; then echo "Backup completed: $destination"; fi
    fi
    exit "$code"
}
trap finish EXIT
trap 'exit 130' HUP INT TERM
# Register cleanup before querying Docker: an unavailable daemon must not leave
# the local backup lock behind. Preserve compose's status rather than a pipeline's.
running=$(compose ps --status running --services)
running=$(printf '%s\n' "$running" | tr '\n' ' ')
case "$mode" in
    online)
        guard=$(compose run --rm --no-deps -T --entrypoint python api -m bmt_backend.backup_guard begin)
        printf '%s\n' "$guard" > "$destination/GC_RECOVERY_TOKEN"
        ;;
    offline) compose stop api worker >&2 ;;
    *) echo "BMT_BACKUP_MODE must be online or offline" >&2; exit 2 ;;
esac
compose exec -T db pg_dump -U postgres -d bmt --format=custom --no-owner --no-privileges > "$destination/database.dump"
compose run --rm --no-deps -T --entrypoint python api /app/deploy/object_archive.py archive > "$destination/objects.tar"
database_container=$(compose ps -q db)
project=$(docker inspect --format '{{ index .Config.Labels "com.docker.compose.project" }}' "$database_container")
printf 'format=bmt-backup-v1\nproject=%s\ncreated_utc=%s\n' "$project" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$destination/backup.info"
(cd "$destination" && sha256sum database.dump objects.tar backup.info > SHA256SUMS)
data_ready=1

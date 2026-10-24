#!/usr/bin/env bash
set -euo pipefail

workspace='/mnt/c/Codes/Godot/Beat my track'
evidence="$workspace/docs/evidence/backend-scale-other-fixes-2026-10-23/studio"
task="bmt-studio-report-$(date +%s)-$$"
network="$task-network"
primary="$task-primary"
replica="$task-replica"
cleanup() {
    docker rm -f "$replica" "$primary" >/dev/null 2>&1 || true
    docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT
ready() {
    for attempt in $(seq 1 100); do
        if docker exec "$1" pg_isready -U postgres -d bmt_studio_reporting >/dev/null 2>&1; then return 0; fi
        sleep .1
    done
    docker logs --tail=30 "$1"
    return 1
}
docker network create "$network" >/dev/null
docker run -d --name "$primary" --network "$network" --cpus=1 --memory=512m --pids-limit=128 \
    --tmpfs /var/lib/postgresql/data:rw,size=256m \
    -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=bmt_studio_reporting \
    postgres:16 -c shared_buffers=32MB -c max_wal_size=128MB >/dev/null
ready "$primary"
docker exec "$primary" sh -c 'printf "host replication all 0.0.0.0/0 trust\n" >> "$PGDATA/pg_hba.conf"'
docker exec "$primary" psql -U postgres -d bmt_studio_reporting -c 'SELECT pg_reload_conf()' >/dev/null
docker run -d --name "$replica" --network "$network" --cpus=1 --memory=512m --pids-limit=128 \
    --tmpfs /var/lib/postgresql/data:rw,size=256m -e REPORT_PRIMARY="$primary" \
    --entrypoint sh postgres:16 -c 'install -d -m 0700 -o postgres -g postgres "$PGDATA"; gosu postgres pg_basebackup -h "$REPORT_PRIMARY" -U postgres -D "$PGDATA" -X stream -R; exec gosu postgres postgres -c shared_buffers=32MB -c max_wal_size=128MB' >/dev/null
ready "$replica"
docker run --rm --network "$network" --cpus=2 --memory=1g --pids-limit=128 \
    -v "$workspace/backend:/task/backend:ro" -v "$evidence:/evidence" \
    -e PYTHONPATH=/task/backend -e PYTHONDONTWRITEBYTECODE=1 \
    -e REPORT_PRIMARY="$primary" -e REPORT_REPLICA="$replica" \
    -w /task/backend --entrypoint python bmt-full-20261018:86d38519ffb5ac1f \
    /evidence/physical_replica_probe.py

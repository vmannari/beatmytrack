#!/bin/sh
# Empty-volume bootstrap only. Existing installations require an owner-run cutover.
set -eu
for credential in "$BMT_MIGRATOR_DB_PASSWORD" "$BMT_API_DB_PASSWORD" "$BMT_WORKER_DB_PASSWORD" "$BMT_ADMIN_DB_PASSWORD"; do
  test "${#credential}" -ge 32 || { echo 'Database passwords must be at least 32 characters' >&2; exit 1; }
done
test "$BMT_API_DB_PASSWORD" != "$BMT_WORKER_DB_PASSWORD" &&
test "$BMT_API_DB_PASSWORD" != "$BMT_ADMIN_DB_PASSWORD" &&
test "$BMT_WORKER_DB_PASSWORD" != "$BMT_ADMIN_DB_PASSWORD" &&
test "$BMT_MIGRATOR_DB_PASSWORD" != "$BMT_API_DB_PASSWORD" &&
test "$BMT_MIGRATOR_DB_PASSWORD" != "$BMT_WORKER_DB_PASSWORD" &&
test "$BMT_MIGRATOR_DB_PASSWORD" != "$BMT_ADMIN_DB_PASSWORD" || { echo 'Use distinct workload database passwords' >&2; exit 1; }
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 \
  --set migrator_password="$BMT_MIGRATOR_DB_PASSWORD" \
  --set api_password="$BMT_API_DB_PASSWORD" \
  --set worker_password="$BMT_WORKER_DB_PASSWORD" \
  --set admin_password="$BMT_ADMIN_DB_PASSWORD" <<'SQL'
CREATE ROLE bmt_migrator LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'migrator_password';
CREATE ROLE bmt_api LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'api_password';
CREATE ROLE bmt_worker LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'worker_password';
CREATE ROLE bmt_admin LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'admin_password';
GRANT CONNECT ON DATABASE bmt TO bmt_migrator,bmt_api,bmt_worker,bmt_admin;
ALTER SCHEMA public OWNER TO bmt_migrator;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL

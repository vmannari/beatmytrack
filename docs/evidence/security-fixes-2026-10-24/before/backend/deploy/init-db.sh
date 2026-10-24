#!/bin/sh
# The official Postgres image runs this only on an empty data directory.
set -eu
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --set ON_ERROR_STOP=1 \
  --set app_password="$BMT_DB_PASSWORD" <<'SQL'
CREATE ROLE bmt LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'app_password';
GRANT CONNECT ON DATABASE bmt TO bmt;
ALTER SCHEMA public OWNER TO bmt;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL

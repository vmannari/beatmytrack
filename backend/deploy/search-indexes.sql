-- Optional PostgreSQL substring-search indexes; run with an authorized DB owner
-- after migration and a backup. No application runtime privileges are expanded.
-- Build concurrently outside a transaction on an existing large installation.
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_version_name_trgm
    ON track_versions USING gin (lower(name) public.gin_trgm_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_player_name_trgm
    ON players USING gin (lower(display_name) public.gin_trgm_ops);

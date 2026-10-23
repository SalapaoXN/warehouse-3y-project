-- Run after dbt build, as the same PostgreSQL role that dbt uses.
-- This exposes the star schema (ss_dw) and reporting tables (ss_mart) to Metabase.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_roles WHERE rolname = 'metabase_reader'
    ) THEN
        CREATE ROLE metabase_reader LOGIN;
    END IF;
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO metabase_reader', current_database()
    );
END
$$;

ALTER ROLE metabase_reader LOGIN;
GRANT USAGE ON SCHEMA ss_mart TO metabase_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ss_mart TO metabase_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA ss_mart
    GRANT SELECT ON TABLES TO metabase_reader;

GRANT USAGE ON SCHEMA ss_dw TO metabase_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ss_dw TO metabase_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA ss_dw
    GRANT SELECT ON TABLES TO metabase_reader;

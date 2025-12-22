-- Creates the Rails multi-db databases used by config/database.yml.
-- This runs automatically on first container init when db-data is empty.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_development') THEN
    CREATE DATABASE health_development;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_test') THEN
    CREATE DATABASE health_test;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_cache') THEN
    CREATE DATABASE health_cache;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_queue') THEN
    CREATE DATABASE health_queue;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_cable') THEN
    CREATE DATABASE health_cable;
  END IF;
END
$$;

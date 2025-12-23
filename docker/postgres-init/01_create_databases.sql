-- Creates the Rails multi-db databases used by config/database.yml.
-- This runs automatically on first container init when db-data is empty.

-- NOTE: CREATE DATABASE cannot run inside a DO block (it requires autocommit).
-- psql's \gexec executes the returned SQL as a top-level statement.

SELECT format('CREATE DATABASE %I', 'health_development')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_development')
\gexec

SELECT format('CREATE DATABASE %I', 'health_test')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_test')
\gexec

SELECT format('CREATE DATABASE %I', 'health_cache')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_cache')
\gexec

SELECT format('CREATE DATABASE %I', 'health_queue')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_queue')
\gexec

SELECT format('CREATE DATABASE %I', 'health_cable')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'health_cable')
\gexec

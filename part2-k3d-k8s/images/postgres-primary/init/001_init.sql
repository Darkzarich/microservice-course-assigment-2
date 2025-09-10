
-- demo data + replication user
CREATE USER repl REPLICATION LOGIN ENCRYPTED PASSWORD 'repl';
CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY, name TEXT NOT NULL);
INSERT INTO users(name) VALUES ('Alice'), ('Bob'), ('Carol');
ALTER SYSTEM SET wal_level = replica;
ALTER SYSTEM SET max_wal_senders = 10;
ALTER SYSTEM SET hot_standby = on;
SELECT pg_reload_conf();

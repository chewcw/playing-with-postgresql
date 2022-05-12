#!/usr/bin/env bash

set -e

# Start the postgres container
docker compose up -d postgres
sleep 5

# Wait for the database to be ready
elapsed=0
timeout=60
while true; do
    docker logs postgres 2>&1 | grep -q "database system is ready"
    if [ $? -eq 0 ]; then
        break
    fi
    echo "Waiting for postgresql server to be ready..."
    sleep 1
    elapsed=$((elapsed+1))
    if [ $elapsed -ge $timeout ]; then
        echo "Timed out waiting for postgresql server to be ready."
        exit 1
    fi
done

# Simulate write some messages to the database
echo "Starting database writer..."
docker compose up -d db-writer
sleep 5

# Enable replication on postgres
docker exec -i postgres bash <<'EOF'
set -e

echo "Enabling replication settings..."

# 1. Create replication user (if not exists)
psql -U user -d postgres <<'SQL'
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
      CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'rep_secret';
   END IF;
   IF NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = 'rep_slot_1') THEN
      PERFORM pg_create_physical_replication_slot('rep_slot_1');
   END IF;
END$$;
SQL

# 2. Append pg_hba.conf entry (idempotent)
if ! grep -q "host replication replicator .* md5" /var/lib/postgresql/data/pg_hba.conf; then
  echo "host replication replicator 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
fi

# 3. Set WAL parameters via ALTER SYSTEM
psql -U user -d postgres<<SQL
ALTER SYSTEM SET wal_level = replica;
ALTER SYSTEM SET max_wal_senders = 10;
ALTER SYSTEM SET wal_keep_size = '64MB';
ALTER SYSTEM SET hot_standby = on;
SQL

# 4. Reload configuration
psql -U user -d postgres -c "SELECT pg_reload_conf();"
EOF

sleep 5

# Add a new replica service manually (join mid-flight)
echo "Starting replica..."
docker compose up -d replica
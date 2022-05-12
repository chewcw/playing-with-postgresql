#!/usr/bin/env bash

set -e

sleep 5

psql -h postgres_primary -U user -d postgres -c "
CREATE TABLE IF NOT EXISTS counter (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMPZ DEFAULT NOW()
  );
"

while true; do
  psql -h postgres_primary -U user -d postgres -c \
    "INSERT INTO counter (ts) VALUES (now());"
  echo "Inserted a new row into counter table."
  sleep 5;
done

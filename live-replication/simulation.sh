#!/usr/bin/env bash

set -e

sleep 5

psql -h postgres -U user -d postgres -c "
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMP DEFAULT NOW()
  );
"

while true; do
  psql -h postgres -U user -d postgres -c \
    "INSERT INTO messages (ts) VALUES (now());"
  echo "Inserted a new row into messages table."
  sleep 5;
done

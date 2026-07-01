#!/usr/bin/env bash
# Load the FAILING dataset into Postgres, overwriting whatever is there.
# Same schema (DB_SCHEMA in ../.env) and same table names as load_clean.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if [ ! -d ./failing ]; then
  echo "./failing not found — run ./generate_data.sh first." >&2
  exit 1
fi

uv run --with "psycopg[binary]" load_to_postgres.py --source ./failing

#!/usr/bin/env bash
# Load the CLEAN dataset into Postgres, overwriting whatever is there.
# Same schema (DB_SCHEMA in ../.env) and same table names as load_failing.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if [ ! -d ./clean ]; then
  echo "./clean not found — run ./generate_data.sh first." >&2
  exit 1
fi

uv run --with "psycopg[binary]" load_to_postgres.py --source ./clean

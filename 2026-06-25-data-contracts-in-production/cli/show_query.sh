#!/usr/bin/env bash
# Print the ONE SQL query Soda compiles from the contract's data checks — just that
# query, once (not the schema-metadata query, not the per-run repeats).
#
#   ./show_query.sh [contract.yml]
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE"
cd "$ROOT"
set -a; . "$ROOT/../.env"; set +a
. "$ROOT/.venv/bin/activate"

CONTRACT="${1:-customers.contract.yml}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

# Run verbose; the SQL is identical regardless of which data is loaded.
SODA_DEBUG_PRINT_SQL_MAX_CHARS=100000 \
  soda contract verify -c "$CONTRACT" -ds postgres.yml -v > "$LOG" 2>&1 || true

# Extract the first WITH … ; block that actually contains the check logic.
sed 's/\x1b\[[0-9;]*m//g' "$LOG" | awk '
  /^WITH/        { cap=1; buf="" }
  cap            { buf = buf $0 ORS }
  cap && /;[[:space:]]*$/ {
                   if (buf ~ /CASE WHEN/) { printf "%s", buf; exit }
                   cap=0 }
'

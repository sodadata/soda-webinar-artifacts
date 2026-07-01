#!/usr/bin/env bash
#
# prep.sh — reset the demo to a known faulty state:
#   1. clean.sh --yes  : delete ALL Soda Cloud datasets for the datasource
#   2. load failing CSVs into Postgres (overwriting existing tables)
#
# Step 1 cascades-deletes contracts/checks/monitors/scans/incidents in Soda Cloud
# (not the Postgres tables). Step 2 then (re)creates the tables from data/failing/*.csv
# via the existing loader, which reads DB creds from ../.env.
#
# Usage:
#   ./prep.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(cd "$SCRIPT_DIR/../data" && pwd)"

echo "==> [1/2] Deleting all Soda Cloud datasets (clean.sh --yes) ..."
# --force skips clean.sh's interactive type-the-name confirmation so prep runs unattended.
"$SCRIPT_DIR/clean.sh" --yes --force

echo
echo "==> [2/2] Loading FAILING data into Postgres ..."
"$DATA_DIR/load_failing.sh"

echo
echo "==> prep complete: Soda datasets cleared and faulty data loaded."

#!/usr/bin/env bash
# Soda data-contract demo — key-advance, auto-typing terminal walkthrough.
#
#   Load failing data -> generate contract -> add checks -> verify (FAILS)
#   -> load clean data -> verify (PASSES). Results published to Soda Cloud.
#   (Cleanup is NOT automatic — the results stay in Soda Cloud for inspection.)
#
# Press any key to advance / to run each command. Ctrl-C to bail.
#
#   ./demo.sh                 # normal pace
#   TYPE_SPEED=0 ./demo.sh    # instant typing (rehearsal)
#   RESET_ONLY=1 ./demo.sh    # just restore the repo to its pre-demo state
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE"                            # the cli/ dir
cd "$ROOT"

source "$HERE/lib.sh"

# --- environment: credentials from ../.env + the demo venv -------------------
set -a; . "$ROOT/../.env"; set +a
. "$ROOT/.venv/bin/activate"

# Make sure the Soda CLI (sodacli) is authenticated — silent, no secret on screen.
sodacli auth login --host "https://${SODA_CLOUD_HOST#https://}" \
  --api-key-id "$SODA_API_KEY_ID" --api-key-secret "$SODA_API_KEY_SECRET" >/dev/null 2>&1 || true

# The Soda Cloud data source "soda_webinar_20260625" is a persistent, runner-backed
# fixture: its credentials live in a Cloud secret (not here), and an online Soda
# Runner reaches Postgres on its behalf. --use-runner verifies against it, so we do
# NOT delete/recreate it each run — that's what keeps the contract history intact.

CONTRACT="customers.contract.yml"
DATASET="soda_webinar_20260625/postgres/soda_webinar_20260625/customers"

BACKUP="$HERE/.contract.backup"

restore() {
  [ -f "$BACKUP" ] && mv "$BACKUP" "$ROOT/$CONTRACT"
}
# Snapshot whatever contract is there now, and put it back when we exit.
[ -f "$ROOT/$CONTRACT" ] && cp "$ROOT/$CONTRACT" "$BACKUP"
trap restore EXIT
rm -f "$ROOT/$CONTRACT"

if [ "${RESET_ONLY:-0}" = "1" ]; then restore; trap - EXIT; echo "Restored $CONTRACT."; exit 0; fi

clear

# --- 1. load the FAILING data -----------------------------------------------
say "Step 1 — load a messy extract into the warehouse."
cmd "bash ../data/load_failing.sh"

# --- 2. generate a basic contract -------------------------------------------
say "Step 2 — generate a basic contract straight from the table's metadata."
cmd "soda contract create -d $DATASET -ds postgres.yml -f $CONTRACT"
say "The skeleton: every column, its data type, and a schema check."
cmd "cat $CONTRACT"

# --- 3. add some checks (manual edit) ---------------------------------------
say "Step 3 — open the contract and add data-quality checks by hand."
editfile "$ROOT/$CONTRACT" < "$HERE/parts/customers.full.contract.yml"
say "Quick syntax check before we run it."
cmd "soda contract test -c $CONTRACT"
say "Those checks compile to ONE query — a single pass over the table."
cmd "./show_query.sh"

# --- 4. verify the messy data, publish results (RED in Soda Cloud) ----------
say "Step 4 — verify the messy data on the Soda Runner and send results to Cloud. Expect failures."
cmd "soda contract verify -c $CONTRACT -sc soda_cloud.yml --use-runner --publish"

# --- 5. load the CLEAN data -------------------------------------------------
say "Step 5 — the upstream issue is fixed; reload the clean data."
cmd "bash ../data/load_clean.sh"

# --- 6. verify again, publish results (GREEN in Soda Cloud) -----------------
say "Step 6 — verify again on the runner and publish. Same contract, clean data."
cmd "soda contract verify -c $CONTRACT -sc soda_cloud.yml --use-runner --publish"

# --- the distilled commands, as you'd use them in a pipeline ----------------
cat <<EOF

  Key command for a pipeline stage

  Every run (runner reaches the warehouse — no DB creds on the CI worker):
${_C_CMD}soda contract verify -c $CONTRACT -sc soda_cloud.yml --use-runner --publish${_C_RST}
  # exit 0 = passed · exit 1 = a check failed → fail the stage
EOF

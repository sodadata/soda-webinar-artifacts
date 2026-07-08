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

# --- environment: credentials from ../.env -----------------------------------
set -a; . "$ROOT/../.env" 2>/dev/null; set +a

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

# --- Python env: soda-core from public PyPI (built fresh if missing) ---------
# soda-core + soda-postgres are all this demo needs to VERIFY a contract and
# publish results to Soda Cloud. `soda contract create` (Step 2) additionally
# needs Soda's extensions library, which is NOT on public PyPI. We detect it
# below; if it's absent we stand in with a pre-generated skeleton so the rest of
# the demo still runs. Reuse an already-working venv (it may include extensions);
# otherwise build a clean one from public PyPI.
ensure_venv() {
  if [ -x "$ROOT/.venv/bin/python" ] \
     && "$ROOT/.venv/bin/python" -c "import soda_core" >/dev/null 2>&1 \
     && "$ROOT/.venv/bin/soda" --help >/dev/null 2>&1; then
    :   # existing, working venv — reuse as-is
  else
    echo "Setting up a Python virtualenv with soda-core (public PyPI)…"
    rm -rf "$ROOT/.venv"
    python3 -m venv "$ROOT/.venv"
    "$ROOT/.venv/bin/python" -m pip install --quiet --upgrade pip
    "$ROOT/.venv/bin/python" -m pip install --quiet soda-core soda-postgres
  fi
  . "$ROOT/.venv/bin/activate"
}
ensure_venv

# Is Soda's extensions library (provides `soda contract create`) importable?
if python -c "import soda.contract_generator" >/dev/null 2>&1; then
  HAS_EXTENSIONS=1
else
  HAS_EXTENSIONS=0
fi

clear

# --- 1. load the FAILING data -----------------------------------------------
say "Step 1 — load a messy extract into the warehouse."
cmd "bash ../data/load_failing.sh"

# --- 2. generate a basic contract -------------------------------------------
say "Step 2 — generate a basic contract straight from the table's metadata."
if [ "$HAS_EXTENSIONS" = "1" ]; then
  cmd "soda contract create -d $DATASET -ds postgres.yml -f $CONTRACT"
else
  note "'soda contract create' ships in Soda's extensions library, which isn't on public PyPI."
  note "Standing in with a pre-generated skeleton — identical to what the generator emits."
  cmd "cp parts/customers.skeleton.contract.yml $CONTRACT"
fi
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

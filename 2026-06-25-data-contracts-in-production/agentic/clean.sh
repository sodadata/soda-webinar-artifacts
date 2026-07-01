#!/usr/bin/env bash
#
# clean.sh — delete ALL Soda Cloud datasets belonging to a datasource (default:
#            soda_webinar_20260625) via the Soda Cloud REST API.
#
# DESTRUCTIVE & IRREVERSIBLE. Deleting a dataset cascades to its contracts, checks,
# monitors, scans, incidents, profiling and history. It does NOT drop the underlying
# Postgres tables — only the Soda Cloud tracking objects. Deletion is async server-side,
# so counts drain over a few minutes after the calls return.
#
# Usage:
#   ./clean.sh                       # DRY RUN: list what would be deleted, delete nothing
#   ./clean.sh --yes                 # delete (after typing the datasource name to confirm)
#   ./clean.sh --yes --force         # delete with no interactive prompt (for CI/scripts)
#   DATASOURCE=other_ds ./clean.sh   # target a different datasource by exact name
#
# Creds are read from .env (SODA_CLOUD_HOST, SODA_API_KEY_ID, SODA_API_KEY_SECRET).

set -euo pipefail

DATASOURCE="${DATASOURCE:-soda_webinar_20260625}"
APPLY=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y)   APPLY=true ;;
    --force|-f) FORCE=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
[[ -f "$ENV_FILE" ]] || { echo "ERROR: .env not found at $ENV_FILE" >&2; exit 1; }
command -v jq   >/dev/null || { echo "ERROR: jq is required"   >&2; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl is required" >&2; exit 1; }

# Read only the keys we need (avoid sourcing .env — it holds a JSON blob and comments).
getenv() { grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2-; }
HOST="$(getenv SODA_CLOUD_HOST)"
KEY_ID="$(getenv SODA_API_KEY_ID)"
KEY_SECRET="$(getenv SODA_API_KEY_SECRET)"
[[ -n "$HOST" && -n "$KEY_ID" && -n "$KEY_SECRET" ]] \
  || { echo "ERROR: missing SODA_CLOUD_HOST / SODA_API_KEY_ID / SODA_API_KEY_SECRET in $ENV_FILE" >&2; exit 1; }
[[ "$HOST" == http* ]] || HOST="https://$HOST"
HOST="${HOST%/}"

api() { curl -fsS -u "$KEY_ID:$KEY_SECRET" "$@"; }

# Collect dataset ids for the EXACT datasource name. datasourceName is a fuzzy/partial
# server-side filter (it also matches e.g. soda_webinar_20260625_rh024358), so we match
# the exact name client-side and paginate.
echo "Resolving datasets for datasource '$DATASOURCE' on $HOST ..." >&2
ids=(); names=(); page=0
while :; do
  resp="$(api "$HOST/api/v1/datasets?datasourceName=$DATASOURCE&size=1000&page=$page")"
  while IFS=$'\t' read -r id name; do
    [[ -z "$id" ]] && continue
    ids+=("$id"); names+=("$name")
  done < <(echo "$resp" | jq -r --arg ds "$DATASOURCE" \
            '.content[] | select(.datasource.name == $ds) | "\(.id)\t\(.name)"')
  [[ "$(echo "$resp" | jq -r '.last // true')" == "true" || $page -ge 50 ]] && break
  page=$((page+1))
done

count=${#ids[@]}
if [[ $count -eq 0 ]]; then
  echo "No datasets found for datasource '$DATASOURCE'. Nothing to do."
  exit 0
fi

echo
echo "Found $count dataset(s) in '$DATASOURCE':"
for i in "${!ids[@]}"; do printf '  %s  %s\n' "${ids[$i]}" "${names[$i]}"; done
echo

if ! $APPLY; then
  echo "DRY RUN — nothing deleted. Re-run with --yes to delete these datasets."
  exit 0
fi

if ! $FORCE; then
  read -r -p "Permanently delete these $count dataset(s) and ALL their contracts/checks/monitors/scans/incidents? Type the datasource name to confirm: " confirm
  [[ "$confirm" == "$DATASOURCE" ]] || { echo "Confirmation did not match. Aborted."; exit 1; }
fi

fail=0
for i in "${!ids[@]}"; do
  printf 'Deleting %s (%s) ... ' "${names[$i]}" "${ids[$i]}"
  if api -X DELETE "$HOST/api/v1/datasets/${ids[$i]}" -o /dev/null; then
    echo "ok"
  else
    echo "FAILED"; fail=$((fail+1))
  fi
done

echo
if [[ $fail -eq 0 ]]; then
  echo "Done. Deletion is async server-side; dataset/contract counts drain over a few minutes."
else
  echo "Completed with $fail failure(s)." >&2; exit 1
fi

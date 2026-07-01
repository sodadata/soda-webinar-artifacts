#!/usr/bin/env bash
# Clears ALL poll votes (resets the live results to zero).
# Safe to run anytime — e.g. after a rehearsal, or right before the webinar starts.
set -euo pipefail

# All config comes from ../.env — nothing is hardcoded or committed.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/../.env" ] && { set -a; . "$HERE/../.env"; set +a; }

URL="${SUPABASE_URL:?set SUPABASE_URL in ../.env}"
KEY="${SUPABASE_KEY:?set SUPABASE_KEY in ../.env}"
SECRET="${CLEAR_SECRET:?set CLEAR_SECRET in ../.env (never commit it)}"

read -r -p "Delete ALL poll votes? This cannot be undone. [y/N] " ans
case "$ans" in
  y|Y|yes|YES) ;;
  *) echo "Aborted."; exit 0 ;;
esac

echo "Clearing votes…"
deleted=$(curl -s -X POST "$URL/rest/v1/rpc/clear_votes" \
  -H "apikey: $KEY" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"p_secret\":\"$SECRET\"}")

echo "Done. Rows deleted: ${deleted}"
echo "Open results to confirm: ${URL%.co}.co  ->  https://poll-seven-dusky.vercel.app/?view=results"

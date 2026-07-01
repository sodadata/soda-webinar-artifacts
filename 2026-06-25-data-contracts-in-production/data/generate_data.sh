#!/usr/bin/env bash
# Generate both the clean and failing CSV datasets.
#
#   clean/    -> no data-quality issues (every Soda check passes)
#   failing/  -> the planted DQ issues from DATA_QUALITY_ISSUES.md
#
# Pure standard-library Python; reproducible (seed=42).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

python3 generate_data.py --mode clean   --out ./clean
python3 generate_data.py --mode failing --out ./failing

echo
echo "Generated:"
echo "  $HERE/clean/    (clean dataset)"
echo "  $HERE/failing/  (failing dataset)"

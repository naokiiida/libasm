#!/usr/bin/env bash
set -euo pipefail

REF_FILE="$(dirname "$0")/../references/x86_64_instructions.md"

if [ $# -lt 1 ]; then
  cat "$REF_FILE"
  exit 0
fi

QUERY="$1"
grep -i -A 18 -E "^### \`?${QUERY}\b" "$REF_FILE" || {
  echo "No exact section for '$QUERY' in local cheat sheet. Showing matching lines:"
  grep -i -n -C 3 "$QUERY" "$REF_FILE" || true
}

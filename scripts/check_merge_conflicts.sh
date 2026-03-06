#!/usr/bin/env bash
set -euo pipefail

# Quick merge-conflict diagnosis helper.

has_conflict=0

echo "== Git unmerged paths =="
unmerged=$(git diff --name-only --diff-filter=U || true)
if [ -n "$unmerged" ]; then
  has_conflict=1
  echo "$unmerged"
else
  echo "(none)"
fi

echo
echo "== Conflict markers in tracked files =="
# Limit to tracked files to avoid scanning huge generated outputs.
marker_hits=$(git ls-files -z | xargs -0 rg -n "^(<<<<<<<|=======|>>>>>>>)" -S || true)
if [ -n "$marker_hits" ]; then
  has_conflict=1
  echo "$marker_hits"
else
  echo "(none)"
fi

echo
echo "== Summary =="
if [ "$has_conflict" -eq 1 ]; then
  echo "Conflicts detected. Resolve files listed above."
  exit 1
else
  echo "No merge conflicts detected in current working tree."
fi

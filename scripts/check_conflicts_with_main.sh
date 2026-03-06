#!/usr/bin/env bash
set -euo pipefail

# Predict merge conflict hotspots against a target branch (default: main).
# Usage:
#   scripts/check_conflicts_with_main.sh [target-branch]

TARGET="${1:-main}"

if ! git rev-parse --verify "$TARGET" >/dev/null 2>&1; then
  echo "[WARN] target branch '$TARGET' not found locally."
  echo "       Fetch or create it first, e.g. git fetch origin main:main"
  exit 2
fi

BASE=$(git merge-base HEAD "$TARGET")

echo "== Merge base =="
echo "$BASE"

echo
echo "== True unresolved conflicts in working tree =="
unmerged=$(git diff --name-only --diff-filter=U || true)
if [ -n "$unmerged" ]; then
  echo "$unmerged"
else
  echo "(none)"
fi

echo
echo "== Files changed on current branch since merge-base =="
ours=$(git diff --name-only "$BASE"..HEAD | sort -u)
if [ -n "$ours" ]; then
  echo "$ours"
else
  echo "(none)"
fi

echo
echo "== Files changed on $TARGET since merge-base =="
theirs=$(git diff --name-only "$BASE".."$TARGET" | sort -u)
if [ -n "$theirs" ]; then
  echo "$theirs"
else
  echo "(none)"
fi

echo
echo "== Potential merge-conflict files (both sides touched) =="
potential=$(comm -12 <(printf '%s\n' "$ours" | sed '/^$/d') <(printf '%s\n' "$theirs" | sed '/^$/d') || true)
if [ -n "$potential" ]; then
  echo "$potential"
  echo
  echo "[INFO] These files are most likely to conflict during merge/rebase."
  exit 1
else
  echo "(none)"
  echo
  echo "[INFO] No overlap detected in changed file sets."
fi

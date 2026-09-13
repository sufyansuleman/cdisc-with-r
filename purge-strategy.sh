#!/usr/bin/env bash
# Purge COURSE-STRATEGY.md from all history and force-push.
#
# It lived at TWO paths: the repo root before the notes/ reorg (1aad9e4),
# and notes/ after it. Both are removed.
#
# Backup already taken: ../cdisc-with-r-backup-2.bundle
# To restore:  git clone cdisc-with-r-backup-2.bundle recovered
#
# Run from Git Bash in the repo:  bash purge-strategy.sh
# It aborts before pushing if anything looks wrong.

set -euo pipefail

OLD=56b381aa8fd0652453dbfc6b048d9a9524b27211
cd "$(dirname "$0")"

[ "$(git rev-parse HEAD)" = "$OLD" ] || { echo "ABORT: HEAD is not $OLD"; exit 1; }

# This script is itself untracked in the repo; ignore only itself.
DIRT="$(git status --porcelain | grep -v 'purge-strategy\.sh$' || true)"
if [ -n "$DIRT" ]; then
  echo "ABORT: working tree is dirty:"; echo "$DIRT"; exit 1
fi

echo "== rewriting history (both paths) =="
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --index-filter '
  git rm --cached --ignore-unmatch notes/COURSE-STRATEGY.md COURSE-STRATEGY.md
' --prune-empty -- --all

echo "== check 1: nothing lost except that file =="
if [ -n "$(git diff "$OLD" HEAD --stat)" ]; then
  echo "ABORT: trees differ. NOT pushing."
  git diff "$OLD" HEAD --stat
  exit 1
fi
echo "   ok - working trees identical"

echo "== dropping filter-branch backup refs =="
rm -rf .git/refs/original
git for-each-ref --format='%(refname)' refs/original | while read -r r; do
  git update-ref -d "$r" || true
done
git reflog expire --expire=now --all
git gc --prune=now

echo "== check 2: gone from every ref, both paths =="
LEFT="$(git log --all --oneline -- notes/COURSE-STRATEGY.md COURSE-STRATEGY.md)"
if [ -n "$LEFT" ]; then
  echo "ABORT: still reachable. NOT pushing."; echo "$LEFT"; exit 1
fi
echo "   ok - absent from all history"

echo "== force-pushing (lease pinned to the known remote tip) =="
git push --force-with-lease=refs/heads/main:$OLD origin main

echo "== cleaning up =="
rm -f purge-strategy.sh

echo
echo "DONE. New tip: $(git rev-parse HEAD)"
echo "Tell Claude it is finished and it will verify against a fresh clone."

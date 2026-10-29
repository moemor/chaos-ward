#!/usr/bin/env bash
# One round of data updates (used by .github/workflows/game-data.yml).
# GitHub starts scheduled runs only every few hours, so a scheduled run does several rounds,
# one per hour, to keep the market prices about an hour fresh. A manual run does one round.
set -u
ROUNDS="${1:-1}"
for i in $(seq 1 "$ROUNDS"); do
  echo "== round $i of $ROUNDS =="
  git pull -q --rebase origin main || true
  rm -rf repoe && git clone -q --depth 1 https://github.com/repoe-fork/poe2.git repoe
  python3 tools/update_moddb.py repoe data || echo "mod list failed"
  python3 tools/update_market.py data || echo "market failed"
  # unique prices: every 6 hours, right away when a new league has no list yet, and on a manual run
  LG=$(awk -F'\t' '$1=="L"{print $3; exit}' data/market/index.tsv 2>/dev/null)
  if [ $((10#$(date -u +%H) % 6)) -eq 0 ] || [ "${EVENT:-}" = "workflow_dispatch" ] || [ -z "$LG" ] || [ ! -f "data/uniques/$LG" ]; then
    python3 tools/update_uniques.py repoe data || echo "uniques failed"
  fi
  git add data
  if ! git diff --cached --quiet; then
    git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      commit -q -m "Game data and prices $(date -u +'%Y-%m-%d %H:%M')"
    git pull -q --rebase origin main && git push -q || echo "push failed"
  fi
  [ "$i" -lt "$ROUNDS" ] && sleep 3300
done
exit 0

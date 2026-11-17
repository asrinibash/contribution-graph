#!/usr/bin/env bash
# Makes a random number of empty commits, each at a random time inside a
# daily UTC window, then pushes. Configured through environment variables
# set in .github/workflows/main.yml.
set -euo pipefail

: "${GIT_EMAIL:?GIT_EMAIL secret is not set}"
: "${GIT_NAME:=contribution-bot}"
: "${MIN_COMMITS:=6}" "${MAX_COMMITS:=16}"
: "${WINDOW_START:=17:30:00}" "${WINDOW_END:=20:30:00}"

# Use today's window, or yesterday's if today's has not finished yet
# (e.g. a manual test run), so commits are never dated in the future.
now=$(date -u +%s)
day=$(date -u +%F)
if (( now < $(date -u -d "$day $WINDOW_END" +%s) )); then
  day=$(date -u -d "$day -1 day" +%F)
fi
start=$(date -u -d "$day $WINDOW_START" +%s)
end=$(date -u -d "$day $WINDOW_END" +%s)

# Never Sunday; skip about half of Saturdays.
dow=$(date -u -d "$day" +%u)
if (( dow == 7 )); then
  echo "Sunday ($day): skipping."; exit 0
fi
if (( dow == 6 && RANDOM % 2 == 0 )); then
  echo "Saturday ($day): skipping this week."; exit 0
fi

git config user.name "$GIT_NAME"
git config user.email "$GIT_EMAIL"

n=$(( MIN_COMMITS + RANDOM % (MAX_COMMITS - MIN_COMMITS + 1) ))
times=$(for _ in $(seq "$n"); do
  echo $(( start + (RANDOM * 32768 + RANDOM) % (end - start) ))
done | sort -n)

i=0
for t in $times; do
  i=$(( i + 1 ))
  d=$(date -u -d "@$t" +%Y-%m-%dT%H:%M:%S+0000)
  GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" \
    git commit --allow-empty -q -m "chore: update ($i/$n)"
  echo "Commit $i/$n at $d"
done

git push

#!/usr/bin/env bash
# Prints the full messages of the commits in a push, for detect_release.sh.
#
# Read from git history rather than the webhook payload, so it works for any
# number of commits (the payload is capped at 20) and for every event type.
#
# Usage: tool/ci/commit_messages.sh [BEFORE_SHA] [HEAD_SHA]
#   BEFORE_SHA  the tip before the push; empty/all-zeros/unknown (new branch,
#               force-push) means "just the head commit".
#   HEAD_SHA    defaults to HEAD.
set -euo pipefail

before="${1:-}"
head="${2:-HEAD}"
zeros="0000000000000000000000000000000000000000"

if [[ -n "$before" && "$before" != "$zeros" ]] && git cat-file -e "${before}^{commit}" 2>/dev/null; then
  git log --format=%B "${before}..${head}"
else
  git log -1 --format=%B "$head"
fi

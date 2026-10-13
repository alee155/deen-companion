#!/usr/bin/env bash
# Decides whether this pipeline run should produce release builds.
#
# A release is built only when ALL of these hold:
#   1. the event is a push (never a pull request — PRs can come from forks and
#      must not get access to signing credentials),
#   2. the branch is one of RELEASE_BRANCHES,
#   3. a commit message in the push contains RELEASE_TOKEN (case-insensitive).
#
# Inputs (environment):
#   EVENT_NAME        github.event_name
#   REF_NAME          github.ref_name
#   COMMIT_MESSAGES   all commit messages of the push (any text; searched as-is)
#   RELEASE_TOKEN     default "[Release]"
#   RELEASE_BRANCHES  space-separated glob patterns, default "main release/*"
#
# Output: `release=true|false` and `reason=<text>` on stdout, suitable for
# appending to $GITHUB_OUTPUT. Human-readable log goes to stderr.
set -euo pipefail

: "${EVENT_NAME:?EVENT_NAME is required}"
: "${REF_NAME:?REF_NAME is required}"
messages="${COMMIT_MESSAGES:-}"
token="${RELEASE_TOKEN:-[Release]}"
branches="${RELEASE_BRANCHES:-main release/*}"

release=false
reason=""

if [[ "$EVENT_NAME" != "push" ]]; then
  reason="'$EVENT_NAME' events never produce release builds"
else
  branch_ok=false
  for pattern in $branches; do
    # shellcheck disable=SC2053  # the pattern is meant to be a glob
    if [[ "$REF_NAME" == $pattern ]]; then
      branch_ok=true
      break
    fi
  done

  if [[ "$branch_ok" != true ]]; then
    reason="branch '$REF_NAME' is not a release branch ($branches)"
  elif grep -qiF -- "$token" <<<"$messages"; then
    release=true
    reason="commit message contains $token on '$REF_NAME'"
  else
    reason="no commit message contains $token"
  fi
fi

echo "Release build: $release — $reason" >&2
echo "release=$release"
echo "reason=$reason"

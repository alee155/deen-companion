#!/usr/bin/env bash
# Fails if any Dart file CHANGED since BASE is not `dart format`-clean.
#
# Checking only changed files (a "ratchet") keeps new code consistently
# formatted without forcing a repository-wide reformat commit. Once the whole
# repo is formatted, replace this with:
#   dart format --output=none --set-exit-if-changed lib test
#
# Usage: tool/ci/check_format.sh [BASE_SHA]
#   BASE_SHA defaults to the merge-base with origin/main (or HEAD~1).
set -euo pipefail

base="${1:-}"
zeros="0000000000000000000000000000000000000000"

if [[ -z "$base" || "$base" == "$zeros" ]] || ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
  # New branch / force-push / unreachable base: fall back.
  base="$(git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || true)"
fi

# (A while-read loop rather than `mapfile`, so this also runs on macOS bash 3.)
files=()
if [[ -z "$base" ]]; then
  echo "No base commit to compare against; checking all Dart files." >&2
  while IFS= read -r f; do files+=("$f"); done < <(git ls-files 'lib/*.dart' 'test/*.dart')
else
  echo "Checking Dart files changed since ${base:0:12}" >&2
  while IFS= read -r f; do files+=("$f"); done < <(
    git diff --name-only --diff-filter=ACMR "$base" HEAD -- '*.dart' |
      grep -vE '\.(g|freezed)\.dart$' || true
  )
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No Dart files changed — nothing to check."
  exit 0
fi

printf '  %s\n' "${files[@]}"
if dart format --output=none --set-exit-if-changed "${files[@]}"; then
  echo "All ${#files[@]} changed Dart file(s) are formatted."
else
  echo "::error::Some changed Dart files are not formatted. Run: dart format <files>"
  exit 1
fi

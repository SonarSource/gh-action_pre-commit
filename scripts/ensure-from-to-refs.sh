#!/usr/bin/env bash
# If extra-args --from-ref/--to-ref values are missing locally, run git fetch origin.

set -euo pipefail

case " ${EXTRA_ARGS:-} " in
  *" --all-files "* | *" -a "* | *" --files "* | *" --files="*)
    exit 0
    ;;
esac

refs=()
prev=""
# shellcheck disable=SC2086 # extra-args is a word-split flag list, same as pre-commit run
for arg in ${EXTRA_ARGS:-}; do
  case "$prev" in
    --from-ref | --to-ref | --source | --origin | -s | -o)
      refs+=("$arg")
      prev=""
      continue
      ;;
    *)
      ;;
  esac
  case "$arg" in
    --from-ref=* | --to-ref=* | --source=* | --origin=*)
      refs+=("${arg#*=}")
      prev=""
      ;;
    --from-ref | --to-ref | --source | --origin | -s | -o)
      prev="$arg"
      ;;
    *)
      prev=""
      ;;
  esac
done

for ref in ${refs[@]+"${refs[@]}"}; do
  if git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
    continue
  fi
  echo "Missing ref '${ref}'; running git fetch origin"
  GIT_TERMINAL_PROMPT=0 git fetch origin
  exit 0
done

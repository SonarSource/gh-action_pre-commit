#!/usr/bin/env bash
# Detect whether GITHUB_WORKSPACE is already a clone of this GitHub repository.
#
# Required environment variables:
# - GITHUB_OUTPUT
# - GITHUB_REPOSITORY (owner/repo)
#
# Sets skip_checkout=true when the workspace is a git work tree whose `origin`
# remote matches GITHUB_REPOSITORY (owner/repo only, case-insensitive).

: "${GITHUB_OUTPUT:?}"
: "${GITHUB_REPOSITORY:?}"

owner_repo_from_remote_url() {
  local url="$1"
  url="${url#"${url%%[![:space:]]*}"}"
  url="${url%"${url##*[![:space:]]}"}"
  url="${url%/}"
  url="${url%.git}"

  local rest
  if [[ "$url" == *"://"* ]]; then
    rest="${url#*://}"
    rest="${rest##*@}"
    rest="${rest#*/}"
  else
    rest="${url#*:}"
  fi
  rest="${rest%%\?*}"
  rest="${rest%%#*}"
  rest="${rest%/}"

  if [[ "$rest" != */* ]]; then
    return 1
  fi
  local repo="${rest##*/}"
  local owner_path="${rest%/*}"
  local owner="${owner_path##*/}"
  if [[ -z "$owner" || -z "$repo" ]]; then
    return 1
  fi
  printf '%s/%s\n' "$owner" "$repo"
}

skip_checkout=false

if command -v git >/dev/null 2>&1 \
  && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -n "$origin_url" ]]; then
    origin_owner_repo="$(owner_repo_from_remote_url "$origin_url" || true)"
    expected="$(printf '%s' "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]')"
    actual="$(printf '%s' "${origin_owner_repo}" | tr '[:upper:]' '[:lower:]')"
    if [[ -n "$actual" && "$actual" == "$expected" ]]; then
      skip_checkout=true
    fi
  fi
fi

echo "skip_checkout=${skip_checkout}" >> "${GITHUB_OUTPUT}"
if [[ "${skip_checkout}" == "true" ]]; then
  echo "Workspace is already a clone of ${GITHUB_REPOSITORY}; skipping checkout."
else
  echo "No matching clone of ${GITHUB_REPOSITORY}; will checkout."
fi

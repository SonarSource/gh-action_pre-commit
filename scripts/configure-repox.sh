#!/usr/bin/env bash
# Configure pip, npm, and nodeenv to use authenticated Repox.
#
# Required environment variables:
# - ARTIFACTORY_USERNAME
# - ARTIFACTORY_ACCESS_TOKEN
# - GITHUB_ENV
#
# Optional:
# - REPOX_URL (default: https://repox.jfrog.io)

set -euo pipefail

: "${ARTIFACTORY_USERNAME:?}"
: "${ARTIFACTORY_ACCESS_TOKEN:?}"
: "${GITHUB_ENV:?}"

REPOX_URL="${REPOX_URL:-https://repox.jfrog.io}"
ARTIFACTORY_URL="${REPOX_URL%/}/artifactory"
repox_scheme="${ARTIFACTORY_URL%%://*}"
repox_host="${ARTIFACTORY_URL#https://}"
repox_host="${repox_host#http://}"
repox_hostname="${repox_host%%/*}"

# ConfigParser interpolation treats % as a sequence; escape for pip.conf / nodeenvrc.
ini_escape() {
  printf '%s' "${1//%/%%}"
}

pip_index_url="${repox_scheme}://${ARTIFACTORY_USERNAME}:${ARTIFACTORY_ACCESS_TOKEN}@${repox_host}/api/pypi/sonarsource-pypi/simple"
npm_registry="${ARTIFACTORY_URL}/api/npm/npm"
nodejs_mirror="${repox_scheme}://${ARTIFACTORY_USERNAME}:${ARTIFACTORY_ACCESS_TOKEN}@${repox_host}/nodejs-dist"

echo "::add-mask::${ARTIFACTORY_USERNAME}"
echo "::add-mask::${ARTIFACTORY_ACCESS_TOKEN}"
echo "::add-mask::${pip_index_url}"
echo "::add-mask::${nodejs_mirror}"

umask 077

mkdir -p "${HOME}/.pip"
cat > "${HOME}/.pip/pip.conf" <<EOF
[global]
index-url = $(ini_escape "${pip_index_url}")
EOF
chmod 600 "${HOME}/.pip/pip.conf"

# pre-commit unsets NPM_CONFIG_USERCONFIG for language: node hooks, so a
# globalconfig file is required in addition to ~/.npmrc.
npmrc="${RUNNER_TEMP:-${HOME}}/repox.npmrc"
cat > "${npmrc}" <<EOF
registry=${npm_registry}
always-auth=true
//${repox_host}/api/npm/:_authToken=${ARTIFACTORY_ACCESS_TOKEN}
EOF
chmod 600 "${npmrc}"
cat >> "${HOME}/.npmrc" <<EOF
registry=${npm_registry}
always-auth=true
//${repox_host}/api/npm/:_authToken=${ARTIFACTORY_ACCESS_TOKEN}
EOF
chmod 600 "${HOME}/.npmrc"

# nodeenv reads ~/.nodeenvrc; it does not honor NODEJS_ORG_MIRROR.
cat > "${HOME}/.nodeenvrc" <<EOF
[nodeenv]
mirror = $(ini_escape "${nodejs_mirror}")
EOF
chmod 600 "${HOME}/.nodeenvrc"

{
  echo "PIP_CONFIG_FILE=${HOME}/.pip/pip.conf"
  echo "PIP_TRUSTED_HOST=${repox_hostname}"
  echo "VIRTUALENV_PIP=embed"
  echo "VIRTUALENV_SETUPTOOLS=embed"
  echo "VIRTUALENV_WHEEL=embed"
  echo "VIRTUALENV_DOWNLOAD=false"
  echo "NPM_CONFIG_GLOBALCONFIG=${npmrc}"
  echo "NPM_CONFIG_REGISTRY=${npm_registry}"
  # node-gyp (and some npm native builds) still read these env vars.
  echo "NODEJS_ORG_MIRROR=${nodejs_mirror}"
  echo "NODE_MIRROR=${nodejs_mirror}"
} >> "${GITHUB_ENV}"

#!/usr/bin/env bash
# Configure pip and npm to use authenticated Repox without config-pip/get-build-number.
#
# Required environment variables:
# - ARTIFACTORY_USERNAME
# - ARTIFACTORY_ACCESS_TOKEN
#
# Optional:
# - REPOX_URL (default: https://repox.jfrog.io)

set -euo pipefail

: "${ARTIFACTORY_USERNAME:?}"
: "${ARTIFACTORY_ACCESS_TOKEN:?}"

REPOX_URL="${REPOX_URL:-https://repox.jfrog.io}"
ARTIFACTORY_URL="${REPOX_URL%/}/artifactory"
repox_host="${ARTIFACTORY_URL#https://}"
repox_host="${repox_host#http://}"

pip_index_url="https://${ARTIFACTORY_USERNAME}:${ARTIFACTORY_ACCESS_TOKEN}@${repox_host}/api/pypi/sonarsource-pypi/simple"
npm_registry="${ARTIFACTORY_URL}/api/npm/npm"

echo "::add-mask::${pip_index_url}"
echo "::add-mask::${ARTIFACTORY_ACCESS_TOKEN}"

mkdir -p "${HOME}/.pip"
cat > "${HOME}/.pip/pip.conf" <<EOF
[global]
index-url = ${pip_index_url}
EOF

mkdir -p "${HOME}/.npm"
cat > "${HOME}/.npmrc" <<EOF
registry=${npm_registry}
//${repox_host}/api/npm/:_authToken=${ARTIFACTORY_ACCESS_TOKEN}
EOF

{
  echo "PIP_INDEX_URL=${pip_index_url}"
  echo "VIRTUALENV_INDEX_URL=${pip_index_url}"
  echo "VIRTUALENV_PIP=embed"
  echo "VIRTUALENV_SETUPTOOLS=embed"
  echo "VIRTUALENV_WHEEL=embed"
  echo "VIRTUALENV_DOWNLOAD=false"
  echo "PIP_TRUSTED_HOST=${repox_host%%/*}"
  echo "NPM_CONFIG_REGISTRY=${npm_registry}"
} >> "${GITHUB_ENV}"

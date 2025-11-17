#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../.." && pwd)
cd "$REPO_ROOT"

log() {
  printf '[local-transparency] %s\n' "$*"
}

ENV_FILE="$REPO_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  log "Loading environment from $ENV_FILE"
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a
else
  log "No .env file found; using defaults"
fi

CONTAINER_CLI=${CONTAINER_CLI:-docker}
GHCR_AUTHFILE=${GHCR_AUTHFILE:-${DOCKER_CONFIG:-$HOME/.docker}/config.json}
SKIP_GHCR_LOGIN=${SKIP_GHCR_LOGIN:-0}

maybe_login_registry() {
  if [ "$SKIP_GHCR_LOGIN" = "1" ]; then
    log "Skipping ghcr.io login (SKIP_GHCR_LOGIN=1)"
    return
  fi

  if [ -z "${GHCR_USERNAME:-}" ] || [ -z "${GHCR_TOKEN:-}" ]; then
    return
  fi

  log "Logging into ghcr.io with ${CONTAINER_CLI}"
  "$CONTAINER_CLI" login ghcr.io -u "$GHCR_USERNAME" -p "$GHCR_TOKEN" >/dev/null

  mkdir -p "$(dirname "$GHCR_AUTHFILE")"
  log "Writing credentials to $GHCR_AUTHFILE for cosign/syft"
  if [ "$CONTAINER_CLI" = "podman" ]; then
    "$CONTAINER_CLI" login --authfile "$GHCR_AUTHFILE" ghcr.io -u "$GHCR_USERNAME" -p "$GHCR_TOKEN" >/dev/null
  else
    DOCKER_CONFIG=$(dirname "$GHCR_AUTHFILE") docker login ghcr.io -u "$GHCR_USERNAME" -p "$GHCR_TOKEN" >/dev/null
  fi
}

maybe_login_registry

log "Running workflow lint"
"$SCRIPT_DIR/lint-workflows.sh"

log "Collecting supply-chain evidence"
"$SCRIPT_DIR/collect-supply-chain-evidence.sh"

log "Done"

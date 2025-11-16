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

REGISTRY=${REGISTRY:-ghcr.io/senticor-ai}

if [ -z "${CONTAINER_CLI:-}" ]; then
  if command -v docker >/dev/null 2>&1; then
    CONTAINER_CLI=docker
  elif command -v podman >/dev/null 2>&1; then
    CONTAINER_CLI=podman
  else
    CONTAINER_CLI=docker
  fi
fi

if [ -z "${SKIP_IMAGETOOLS:-}" ]; then
  if [ "$CONTAINER_CLI" = "podman" ]; then
    SKIP_IMAGETOOLS=1
  else
    SKIP_IMAGETOOLS=0
  fi
fi

if [ "$CONTAINER_CLI" = "podman" ] && [ "$SKIP_IMAGETOOLS" != "1" ]; then
  echo "::warning ::Podman does not implement 'docker buildx imagetools'; setting SKIP_IMAGETOOLS=1" >&2
  SKIP_IMAGETOOLS=1
fi

if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
  if [[ "$remote_url" =~ github.com[:/]+([^/]+/[^/.]+) ]]; then
    GITHUB_REPOSITORY=${BASH_REMATCH[1]}
  else
    GITHUB_REPOSITORY="Senticor-ai/jena-docker"
  fi
fi

if [ -z "${JENA_VERSION:-}" ]; then
  JENA_VERSION=$(grep -m1 'ENV[[:space:]]\+JENA_VERSION' jena/Dockerfile | cut -d= -f2 | tr -d '"' | tr -d "[:space:]" || true)
fi

if [ -z "${FUSEKI_VERSION:-}" ]; then
  FUSEKI_VERSION=$(grep -m1 'ENV[[:space:]]\+FUSEKI_VERSION' jena-fuseki/Dockerfile | cut -d= -f2 | tr -d '"' | tr -d "[:space:]" || true)
fi

for var in REGISTRY GITHUB_REPOSITORY JENA_VERSION FUSEKI_VERSION; do
  if [ -z "${!var:-}" ]; then
    echo "Required environment variable $var is not set" >&2
    exit 1
  fi
done

required_tools=(syft cosign)
if [ "$SKIP_IMAGETOOLS" != "1" ]; then
  required_tools=("$CONTAINER_CLI" "${required_tools[@]}")
fi

for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool '$tool' is not available on PATH" >&2
    exit 1
  fi
done

mkdir -p supply-chain-data

run_and_capture() {
  local output_file=$1
  local description=$2
  shift 2

  if "$@" >"$output_file" 2>&1; then
    echo "Captured ${description} output to ${output_file}"
  else
    local status=$?
    echo "::error ::${description} failed (see ${output_file})" >&2
    tail -n 50 "$output_file" >&2 || true
    return $status
  fi
}

process_image() {
  local image=$1
  local version_var=$2
  local version_value=${!version_var}

  if [ -z "$version_value" ]; then
    echo "Version for ${image} (env ${version_var}) is empty" >&2
    exit 1
  fi

  local ref="${REGISTRY}/${image}:${version_value}"
  local attestation_file="supply-chain-data/${image}-attestations.json"
  local syft_file="supply-chain-data/${image}-syft.spdx.json"
  local cosign_file="supply-chain-data/${image}-cosign.txt"
  local pull_file="supply-chain-data/${image}-pull.log"
  local syft_source="$ref"

  if [ "$CONTAINER_CLI" = "podman" ]; then
    run_and_capture "$pull_file" "podman pull" "$CONTAINER_CLI" pull "$ref"
    syft_source="podman:${ref}"
  fi

  echo "::group::Collecting supply-chain data for ${ref}"
  if [ "$SKIP_IMAGETOOLS" = "1" ]; then
    echo "Skipping imagetools inspect for ${ref} (SKIP_IMAGETOOLS=1)"
  else
    run_and_capture "$attestation_file" "${CONTAINER_CLI} buildx imagetools inspect" \
      "$CONTAINER_CLI" buildx imagetools inspect "$ref" --format '{{json .Attestations}}'
  fi
  run_and_capture "$syft_file" "syft packages" \
    syft packages "$syft_source" -o spdx-json
  run_and_capture "$cosign_file" "cosign verify-attestation" \
    env COSIGN_EXPERIMENTAL=1 cosign verify-attestation \
      --type slsaprovenance \
      --certificate-identity-regexp "https://github.com/${GITHUB_REPOSITORY}/.+" \
      --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
      "$ref"
  echo "::endgroup::"
}

process_image jena JENA_VERSION
process_image jena-fuseki FUSEKI_VERSION

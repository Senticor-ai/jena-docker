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

IMAGETOOLS_OPTIONAL=${IMAGETOOLS_OPTIONAL:-0}
SKIP_COSIGN=${SKIP_COSIGN:-0}

if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
  if [[ "$remote_url" =~ github.com[:/]+([^/]+/[^/.]+) ]]; then
    GITHUB_REPOSITORY=${BASH_REMATCH[1]}
  else
    GITHUB_REPOSITORY="Senticor-ai/jena-docker"
  fi
fi

if [ -z "${REGISTRY:-}" ]; then
  registry_owner=$(printf '%s' "${GITHUB_REPOSITORY%%/*}" | tr '[:upper:]' '[:lower:]')
  REGISTRY="ghcr.io/${registry_owner}"
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
  required_tools=("$CONTAINER_CLI" jq "${required_tools[@]}")
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
    if grep -qi 'denied' "$output_file"; then
      echo "::error ::Registry denied access. Ensure your ghcr.io credentials (.env GHCR_USERNAME/GHCR_TOKEN) have read:packages scope and access to ${REGISTRY} images." >&2
    fi
    return $status
  fi
}

capture_attestations() {
  local ref=$1
  local output_file=$2
  local tmp_output

  tmp_output=$(mktemp)
  if {
    "$CONTAINER_CLI" buildx imagetools inspect "$ref" --raw 2>"$output_file" \
      | jq '.manifests // [] | map(select(.annotations["vnd.docker.reference.type"] == "attestation-manifest"))' >"$tmp_output"
  } 2>>"$output_file"; then
    mv "$tmp_output" "$output_file"
    echo "Captured ${CONTAINER_CLI} buildx imagetools inspect output to ${output_file}"
    return 0
  fi

  local status=$?
  rm -f "$tmp_output"
  return $status
}

process_image() {
  local image=$1
  local version_var=$2
  local version_value=${!version_var}

  if [ -z "$version_value" ]; then
    echo "Version for ${image} (env ${version_var}) is empty" >&2
    exit 1
  fi

  local override_var
  override_var=$(printf '%s_IMAGE_REF' "$(echo "$image" | tr '[:lower:]' '[:upper:]' | tr '-' '_')")
  local ref="${REGISTRY}/${image}:${version_value}"
  if [ -n "${!override_var:-}" ]; then
    ref=${!override_var}
  fi
  local attestation_file="supply-chain-data/${image}-attestations.json"
  local syft_file="supply-chain-data/${image}-syft.spdx.json"
  local syft_cdx_file="supply-chain-data/${image}-syft.cdx.json"
  local cosign_file="supply-chain-data/${image}-cosign.txt"
  local pull_file="supply-chain-data/${image}-pull.log"
  local save_file="supply-chain-data/${image}-image.tar"
  local syft_source=""
  local syft_input=""

  if [[ "$ref" == localhost:* || "$ref" == 127.0.0.1:* || "$ref" == localhost/* || "$ref" == 127.0.0.1/* ]]; then
    echo "Using local image for ${ref}; skipping registry pull"
    syft_source="$ref"
  elif [ "$CONTAINER_CLI" = "podman" ]; then
    run_and_capture "$pull_file" "podman pull" "$CONTAINER_CLI" pull "$ref"
    syft_source="podman:${ref}"
  else
    run_and_capture "$pull_file" "${CONTAINER_CLI} pull" "$CONTAINER_CLI" pull "$ref"
    syft_source="$ref"
  fi

  if [ "$CONTAINER_CLI" = "podman" ]; then
    echo "Saving ${ref} to ${save_file} for Syft scanning"
    run_and_capture "${save_file}.log" "podman save" "$CONTAINER_CLI" save "$ref" --format oci-archive -o "$save_file"
    syft_input="oci-archive:${save_file}"
  else
    syft_input="$syft_source"
  fi

  echo "::group::Collecting supply-chain data for ${ref}"
  if [ "$SKIP_IMAGETOOLS" = "1" ]; then
    echo "Skipping imagetools inspect for ${ref} (SKIP_IMAGETOOLS=1)"
  else
    set +e
    capture_attestations "$ref" "$attestation_file"
    imagetools_status=$?
    set -e
    if [ $imagetools_status -ne 0 ]; then
      tail -n 50 "$attestation_file" >&2 || true
      if grep -qi 'denied' "$attestation_file"; then
        echo "::error ::Registry denied access. Ensure your ghcr.io credentials (.env GHCR_USERNAME/GHCR_TOKEN) have read:packages scope and access to ${REGISTRY} images." >&2
      fi
      if [ "$IMAGETOOLS_OPTIONAL" = "1" ]; then
        echo "::warning ::${CONTAINER_CLI} buildx imagetools inspect failed for ${ref}; continuing because IMAGETOOLS_OPTIONAL=1 (see ${attestation_file})" >&2
      else
        echo "::error ::${CONTAINER_CLI} buildx imagetools inspect failed (see ${attestation_file})" >&2
        return $imagetools_status
      fi
    fi
  fi
  run_and_capture "$syft_file" "syft scan (SPDX)" \
    env SYFT_CHECK_FOR_APP_UPDATE=0 syft scan "$syft_input" --output "spdx-json=$syft_file"
  run_and_capture "$syft_cdx_file" "syft scan (CycloneDX)" \
    env SYFT_CHECK_FOR_APP_UPDATE=0 syft scan "$syft_input" --output "cyclonedx-json=$syft_cdx_file"
  local should_skip_cosign=$SKIP_COSIGN
  if [[ "$ref" == localhost:* || "$ref" == 127.0.0.1:* || "$ref" == localhost/* || "$ref" == 127.0.0.1/* ]]; then
    should_skip_cosign=1
  fi
  if [ "$should_skip_cosign" = "1" ]; then
    echo "Skipping cosign verification for ${ref}"
    echo "Cosign skipped for ${ref}" > "$cosign_file"
  else
    local cosign_types=("slsaprovenance" "slsaprovenance02")
    if cosign verify-attestation --help 2>/dev/null | grep -q 'slsaprovenance1'; then
      cosign_types=("slsaprovenance1" "slsaprovenance" "slsaprovenance02")
    fi

    local cosign_flags=()
    if cosign verify-attestation --help 2>/dev/null | grep -q -- '--experimental-oci11'; then
      cosign_flags+=(--experimental-oci11)
    fi

    local cosign_ok=0
    for cosign_type in "${cosign_types[@]}"; do
      if env COSIGN_EXPERIMENTAL=1 cosign verify-attestation \
        "${cosign_flags[@]}" \
        --type "$cosign_type" \
        --certificate-identity-regexp "https://github.com/${GITHUB_REPOSITORY}/.+" \
        --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
        "$ref" >"$cosign_file" 2>&1; then
        echo "Captured cosign verify-attestation (${cosign_type}) output to ${cosign_file}"
        cosign_ok=1
        break
      fi

      if ! grep -qi 'no matching attestations' "$cosign_file"; then
        break
      fi
    done

    if [ "$cosign_ok" -ne 1 ]; then
      echo "::error ::cosign verify-attestation failed (see ${cosign_file})" >&2
      tail -n 50 "$cosign_file" >&2 || true
      if grep -qi 'denied' "$cosign_file"; then
        echo "::error ::Registry denied access. Ensure your ghcr.io credentials (.env GHCR_USERNAME/GHCR_TOKEN) have read:packages scope and access to ${REGISTRY} images." >&2
      fi
      return 1
    fi
  fi
  echo "::endgroup::"
}

process_image jena JENA_VERSION
process_image jena-fuseki FUSEKI_VERSION

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
TOOLS_DIR="${REPO_ROOT}/.github/tools"
ACTIONLINT_VERSION="1.7.12"
LOCAL_ACTIONLINT="${TOOLS_DIR}/actionlint"

log() {
  printf '[lint-workflows] %s\n' "$*" >&2
}

# shellcheck disable=SC2120
download_actionlint() {
  local os arch tarball url tmpdir
  case "$(uname -s)" in
    Linux) os="linux" ;;
    Darwin) os="darwin" ;;
    *)
      echo "Unsupported OS: $(uname -s)" >&2
      exit 1
      ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac

  tarball="actionlint_${ACTIONLINT_VERSION}_${os}_${arch}.tar.gz"
  url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${tarball}"
  tmpdir=$(mktemp -d)
  log "Downloading actionlint ${ACTIONLINT_VERSION} (${os}/${arch})"
  curl -sSfL "$url" -o "${tmpdir}/${tarball}"
  tar -xzf "${tmpdir}/${tarball}" -C "$tmpdir" actionlint
  mkdir -p "$TOOLS_DIR"
  mv "${tmpdir}/actionlint" "$LOCAL_ACTIONLINT"
  chmod +x "$LOCAL_ACTIONLINT"
  rm -rf "$tmpdir"
}

ensure_actionlint() {
  if [ -n "${ACTIONLINT_BIN:-}" ]; then
    echo "$ACTIONLINT_BIN"
    return
  fi

  if command -v actionlint >/dev/null 2>&1; then
    echo "$(command -v actionlint)"
    return
  fi

  if [ -x "$LOCAL_ACTIONLINT" ]; then
    local current
    current=$("$LOCAL_ACTIONLINT" -version 2>/dev/null | head -n1 || true)
    if [[ "$current" == "${ACTIONLINT_VERSION}"* ]]; then
      echo "$LOCAL_ACTIONLINT"
      return
    fi
  fi

  download_actionlint
  echo "$LOCAL_ACTIONLINT"
}

run_actionlint() {
  local bin
  bin=$(ensure_actionlint)
  log "Using actionlint at ${bin}"
  (cd "$REPO_ROOT" && "$bin" "$@")
}

run_actionlint "$@"

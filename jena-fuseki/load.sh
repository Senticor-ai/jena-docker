#!/bin/bash
#   Licensed to the Apache Software Foundation (ASF) under one or more
#   contributor license agreements.  See the NOTICE file distributed with
#   this work for additional information regarding copyright ownership.
#   The ASF licenses this file to You under the Apache License, Version 2.0
#   (the "License"); you may not use this file except in compliance with
#   the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

set -euo pipefail
shopt -s nullglob

extensions=(rdf ttl owl nt nquads)
default_patterns=()
for e in "${extensions[@]}" ; do
  default_patterns+=("*.${e}" "*.${e}.gz")
done

if [ $# -eq 0 ] ; then
  echo "$0 [DB] [PATTERN ...]"
  echo "Load one or more RDF files into Jena Fuseki TDB database DB."
  echo ""
  echo "Current directory is assumed to be /staging"
  echo ""
  echo 'PATTERNs can be a filename or a shell glob pattern like *ttl'
  echo ""
  echo "If no PATTERN are given, the default patterns are searched:"
  printf '  %s\n' "${default_patterns[@]}"
  echo ""
  echo "Set the environment variable TDBLOADER_OPTS for any additional"
  echo "options to pass to tdbloader, e.g. --graph=https://example.org/graph#name"
  exit 0
fi

cd /staging 2>/dev/null || echo "/staging not found" >&2
echo "Current directory: $(pwd)"

DB=$1
shift

patterns=()
if [ $# -eq 0 ] ; then
  patterns=("${default_patterns[@]}")
  user_supplied_patterns=0
else
  patterns=("$@")
  user_supplied_patterns=1
fi

files=()
for pattern in "${patterns[@]}"; do
  mapfile -t matches < <(compgen -G "$pattern" || true)
  if [ ${#matches[@]} -eq 0 ]; then
    if [ "$user_supplied_patterns" -eq 1 ] ; then
      echo "WARNING: Not found: $pattern" >&2
    fi
    continue
  fi

  for f in "${matches[@]}"; do
    if [ -f "$f" ] ; then
      files+=("$f")
    fi
  done
done

if [ ${#files[@]} -eq 0 ] ; then
  echo "No files found for: " >&2
  printf '%s\n' "${patterns[@]}" >&2
  exit 1
fi

echo "#########"
echo "Loading to Fuseki TDB database $DB:"
echo ""
printf '%s\n' "${files[@]}"
echo "#########"

tdbloader_opts=()
if [ -n "${TDBLOADER_OPTS:-}" ]; then
  # Split the optional extra arguments using the shell's default word-splitting rules.
  read -r -a tdbloader_opts <<< "${TDBLOADER_OPTS}"
fi

exec "$FUSEKI_HOME/tdbloader" \
  "${tdbloader_opts[@]}" \
  "--loc=$FUSEKI_BASE/databases/$DB" \
  "${files[@]}"

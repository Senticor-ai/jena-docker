#!/usr/bin/env bash

set -euo pipefail

runtime="${CONTAINER_RUNTIME:-docker}"
image="${1:-jena-fuseki:test}"
default_port="${FUSEKI_SMOKE_PORT:-3030}"
auth_port="${FUSEKI_SMOKE_AUTH_PORT:-3031}"
default_container="fuseki-upstream-smoke-default-$$"
auth_container="fuseki-upstream-smoke-auth-$$"
tmpdir="$(mktemp -d)"

cleanup() {
  "$runtime" rm -f "$default_container" "$auth_container" >/dev/null 2>&1 || true
  "$runtime" run --rm --entrypoint sh -u 0 -v "$tmpdir:/cleanup" "$image" \
    -c 'chmod -R 0777 /cleanup' >/dev/null 2>&1 || true
  rm -rf "$tmpdir" >/dev/null 2>&1 || true
}

trap cleanup EXIT

fail() {
  echo "$1" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [ "$actual" != "$expected" ]; then
    fail "$message: expected '$expected', got '$actual'"
  fi
}

assert_matches() {
  local value="$1"
  local regex="$2"
  local message="$3"
  if ! printf '%s\n' "$value" | grep -Eq "$regex"; then
    fail "$message: '$value' does not match '$regex'"
  fi
}

http_code() {
  curl -s -o /dev/null -w '%{http_code}' "$@"
}

wait_for_log_message() {
  local container="$1"
  local message="$2"
  local attempts="${3:-120}"

  while [ "$attempts" -gt 0 ]; do
    if "$runtime" logs "$container" 2>&1 | grep -q "$message"; then
      sleep 2
      return 0
    fi
    sleep 1
    attempts=$((attempts - 1))
  done

  echo "Timed out waiting for '$message' in $container" >&2
  "$runtime" logs "$container" 2>&1 || true
  return 1
}

default_base_url="http://127.0.0.1:${default_port}"
auth_base_url="http://127.0.0.1:${auth_port}"

echo "Starting default Fuseki container"
"$runtime" run -d --name "$default_container" -p "${default_port}:3030" \
  -e ADMIN_PASSWORD=testpass123 \
  "$image" >/dev/null

wait_for_log_message "$default_container" "Fuseki is available"

echo "Checking default startup and authentication paths"
assert_eq "$(http_code "${default_base_url}/\$/ping")" "200" "Ping endpoint should be public"
curl -fsS "${default_base_url}/" | grep -qi fuseki
assert_eq "$(http_code "${default_base_url}/\$/server")" "401" "Admin endpoint without auth should be rejected"
assert_eq "$(http_code -u admin:wrongpass "${default_base_url}/\$/server")" "401" "Admin endpoint with bad auth should be rejected"
assert_eq "$(http_code -u admin:testpass123 "${default_base_url}/\$/server")" "200" "Admin endpoint with valid auth should succeed"

echo "Checking admin dataset creation and query path"
curl -fsS -X POST -u admin:testpass123 \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data "dbName=testdb&dbType=tdb2" \
  "${default_base_url}/\$/datasets" >/dev/null

curl -fsS -u admin:testpass123 "${default_base_url}/\$/datasets" | grep -q '"/testdb"'

cat > "$tmpdir/test.ttl" <<'EOF'
@prefix : <http://test.org/> .
:subject :predicate :object .
EOF

curl -fsS -X POST -u admin:testpass123 \
  -H "Content-Type: text/turtle" \
  --data-binary @"$tmpdir/test.ttl" \
  "${default_base_url}/testdb/data" >/dev/null

query_response="$(
  curl -fsS -G --data-urlencode "query=SELECT * WHERE { ?s ?p ?o }" \
    "${default_base_url}/testdb/query"
)"
assert_matches "$query_response" 'test\.org' "Uploaded data should be queryable"

assert_eq "$(http_code -u admin:testpass123 "${default_base_url}/\$/stats")" "200" "Stats endpoint should be available to admin"

echo "Checking upstream-inspired SPARQL Update behavior"
assert_eq "$(
  http_code -X POST -H "Content-Type: application/sparql-update" \
    --data "INSERT DATA { <urn:update-s> <urn:update-p> <urn:update-o> }" \
    "${default_base_url}/testdb/update"
)" "401" "SPARQL Update without auth should be rejected"

assert_eq "$(
  http_code -u admin:testpass123 -X POST -H "Content-Type: application/sparql-update" \
    --data "INSERT DATA { <urn:update-s> <urn:update-p> <urn:update-o> }" \
    "${default_base_url}/testdb/update"
)" "204" "SPARQL Update with admin auth should succeed"

update_query_response="$(
  curl -fsS -G --data-urlencode "query=ASK { <urn:update-s> <urn:update-p> <urn:update-o> }" \
    "${default_base_url}/testdb/query"
)"
assert_matches "$update_query_response" '"boolean"[[:space:]]*:[[:space:]]*true' "SPARQL Update should persist data"

echo "Checking upstream-inspired Graph Store Protocol behavior"
assert_eq "$(
  http_code -X PUT -H "Content-Type: text/turtle" \
    --data-binary "<urn:gsp-s> <urn:gsp-p> <urn:gsp-o> ." \
    "${default_base_url}/testdb/data?default"
)" "401" "GSP PUT without auth should be rejected"

assert_eq "$(
  http_code -u admin:testpass123 -X PUT -H "Content-Type: text/turtle" \
    --data-binary "<urn:gsp-s> <urn:gsp-p> <urn:gsp-o> ." \
    "${default_base_url}/testdb/data?default"
)" "200" "GSP PUT with admin auth should succeed"

assert_eq "$(http_code "${default_base_url}/testdb/data?default")" "401" "GSP GET without auth should be rejected"

gsp_get_response="$(curl -fsS -u admin:testpass123 "${default_base_url}/testdb/data?default")"
assert_matches "$gsp_get_response" 'urn:gsp-s' "GSP GET should return inserted triples"

assert_eq "$(
  http_code -u admin:testpass123 -X DELETE "${default_base_url}/testdb/data?default"
)" "204" "GSP DELETE with admin auth should succeed"

gsp_after_delete="$(curl -fsS -u admin:testpass123 "${default_base_url}/testdb/data?default")"
assert_eq "$gsp_after_delete" "" "GSP DELETE should clear the default graph"

echo "Checking log hygiene"
container_logs="$("$runtime" logs "$default_container" 2>&1 || true)"
if printf '%s\n' "$container_logs" | grep -q "admin=testpass123"; then
  fail "Admin password was exposed in container logs"
fi
if printf '%s\n' "$container_logs" | grep -q "Randomly generated"; then
  fail "Container generated a random password even though ADMIN_PASSWORD was set"
fi
if printf '%s\n' "$container_logs" | grep -i "error" >/dev/null; then
  fail "Container logs contain 'error'"
fi

echo "Checking mounted shiro.ini compatibility"
cat > "$tmpdir/shiro.ini" <<'EOF'
[main]
ssl.enabled = false
sessionManager = org.apache.shiro.web.session.mgt.DefaultWebSessionManager
securityManager.sessionManager = $sessionManager
plainMatcher = org.apache.shiro.authc.credential.SimpleCredentialsMatcher
iniRealm.credentialsMatcher = $plainMatcher

[users]
admin = ${ADMIN_PASSWORD}
user1 = passwd1

[roles]

[urls]
/$/status = anon
/$/ping   = anon
/$/** = authcBasic,user[admin]
/*/query/** = authcBasic,user[user1]
/*/sparql/** = authcBasic,user[user1]
/*/get/** = authcBasic,user[user1]
/*/update/** = authcBasic,user[admin]
/*/data/** = authcBasic,user[admin]
/** = anon
EOF

chmod 0777 "$tmpdir"
chmod 0666 "$tmpdir/shiro.ini"

"$runtime" run -d --name "$auth_container" -p "${auth_port}:3030" \
  -e ADMIN_PASSWORD=testpass123 \
  -e FUSEKI_DATASET_1=secure \
  -v "$tmpdir:/fuseki" \
  "$image" >/dev/null

wait_for_log_message "$auth_container" "Fuseki is available"

secure_datasets="$(curl -fsS -u admin:testpass123 "${auth_base_url}/\$/datasets")"
assert_matches "$secure_datasets" '"/secure"' "Mounted shiro.ini container should create the secure dataset"

assert_eq "$(
  http_code -G --data-urlencode "query=ASK{}" "${auth_base_url}/secure/query"
)" "401" "Custom shiro config should reject anonymous dataset queries"

secure_query_response="$(
  curl -fsS -u user1:passwd1 -G --data-urlencode "query=ASK{}" \
    "${auth_base_url}/secure/query"
)"
assert_matches "$secure_query_response" '"boolean"[[:space:]]*:[[:space:]]*true' "Custom shiro config should allow authenticated dataset queries"

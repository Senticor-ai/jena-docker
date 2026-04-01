#!/usr/bin/env bash

set -euo pipefail

runtime="${CONTAINER_RUNTIME:-docker}"
image="${1:-jena:test}"
tmpdir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmpdir"
}

trap cleanup EXIT

cat > "$tmpdir/test.ttl" <<'EOF'
@prefix ex: <http://example.org/> .
ex:subject ex:predicate ex:object .
EOF

cat > "$tmpdir/invalid.ttl" <<'EOF'
INVALID RDF
EOF

cat > "$tmpdir/data.ttl" <<'EOF'
@prefix : <http://example.org/> .
:a :b :c .
EOF

cat > "$tmpdir/query.rq" <<'EOF'
SELECT * WHERE { ?s ?p ?o }
EOF

cat > "$tmpdir/shapes.ttl" <<'EOF'
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix ex: <http://example.org/> .

ex:PersonShape
    a sh:NodeShape ;
    sh:targetClass ex:Person ;
    sh:property [
        sh:path ex:name ;
        sh:minCount 1 ;
    ] .
EOF

cat > "$tmpdir/shacl-data.ttl" <<'EOF'
@prefix ex: <http://example.org/> .
ex:alice a ex:Person .
EOF

echo "Checking riot version"
"$runtime" run --rm "$image" riot --version | grep -q "Apache Jena"

echo "Checking Turtle parsing"
"$runtime" run --rm -v "$tmpdir:/rdf" "$image" riot test.ttl | grep -q "example.org"

echo "Checking invalid RDF rejection"
if "$runtime" run --rm -v "$tmpdir:/rdf" "$image" riot --validate invalid.ttl >/dev/null 2>&1; then
  echo "Expected riot --validate to reject invalid RDF" >&2
  exit 1
fi

echo "Checking arq query execution"
"$runtime" run --rm -v "$tmpdir:/rdf" "$image" arq --data=/rdf/data.ttl --query=/rdf/query.rq | grep -q "example.org"

echo "Checking SHACL validation"
"$runtime" run --rm -v "$tmpdir:/rdf" "$image" \
  shacl validate --shapes=/rdf/shapes.ttl --data=/rdf/shacl-data.ttl \
  | grep -Eq 'sh:conforms[[:space:]]+false'

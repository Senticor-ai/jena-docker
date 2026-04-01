# License Information

This Docker image contains software from multiple sources with different licenses.

## Summary

The images contain components under the following licenses:
- **Apache License 2.0**: Apache Jena, Apache Jena Fuseki, build scripts
- **GPL-2.0 with Classpath Exception**: Eclipse Temurin OpenJDK
- **MIT License**: Various Alpine packages
- **GPL-2.0 and GPL-3.0**: Some Alpine base system components

## Detailed License Breakdown

### Layer 1: Dockerfile and Build Scripts

**License**: Apache License 2.0

All Dockerfiles, shell scripts, and configuration files in this repository are licensed under the Apache License 2.0.

- Copyright: Apache Software Foundation and contributors
- Files: `Dockerfile`, `docker-entrypoint.sh`, `load.sh`, etc.
- SPDX: `Apache-2.0`

### Layer 2: Apache Jena and Fuseki

**License**: Apache License 2.0

- **Apache Jena** (`/jena` in the image)
  - Version: 6.0.0
  - Copyright: The Apache Software Foundation
  - License: Apache License 2.0
  - Homepage: https://jena.apache.org/
  - SPDX: `Apache-2.0`
  - Includes dependencies with compatible licenses (Apache 2.0, MIT, BSD)

- **Apache Jena Fuseki** (`/jena-fuseki` in the image)
  - Version: 6.0.0
  - Copyright: The Apache Software Foundation
  - License: Apache License 2.0
  - Homepage: https://jena.apache.org/documentation/fuseki2/
  - SPDX: `Apache-2.0`

**NOTICE**: See bundled NOTICE files:
```bash
docker run --rm ghcr.io/senticor-ai/jena-fuseki:latest cat /jena-fuseki/NOTICE
```

### Layer 3: Eclipse Temurin OpenJDK

**License**: GPL-2.0 with Classpath Exception

- **Eclipse Temurin JRE 21**
  - Base Image: `eclipse-temurin:25-jre-alpine`
  - Location in image: `/opt/java/openjdk/`
  - Copyright: Eclipse Foundation, Oracle, and contributors
  - License: GNU General Public License v2.0 with Classpath Exception
  - SPDX: `GPL-2.0-with-classpath-exception`
  - Homepage: https://adoptium.net/

The Classpath Exception allows you to link this library with independent modules without making the combined work a derivative work under GPL terms.

**License Details**:
```bash
docker run --rm ghcr.io/senticor-ai/jena-fuseki:latest cat /opt/java/openjdk/legal/java.base/LICENSE
```

### Layer 4: Alpine Linux Base System

**License**: Various (primarily MIT and GPL-2.0)

- **Alpine Linux** 3.x
  - Copyright: Alpine Linux Development Team
  - Primary License: MIT License
  - Some packages: GPL-2.0, GPL-3.0
  - SPDX: `MIT AND GPL-2.0-only AND GPL-3.0-only`
  - Homepage: https://alpinelinux.org/

**Key Packages**:
- `musl libc`: MIT License
- `busybox`: GPL-2.0
- `bash`: GPL-3.0
- `curl`: MIT-like (curl license)
- `ca-certificates`: MPL-2.0 and GPL-2.0
- `coreutils`, `findutils`: GPL-3.0
- `procps`: GPL-2.0 and LGPL-2.1
- `tini`: MIT License
- `pwgen`: GPL-2.0
- `gettext`: GPL-3.0

For detailed Alpine package licenses:
```bash
docker run --rm ghcr.io/senticor-ai/jena-fuseki:latest apk info -L <package-name>
```

## License Compatibility

All licenses in this image are compatible for distribution:

1. **Apache 2.0** (Jena, Fuseki, Dockerfiles): Permissive, allows commercial use
2. **GPL-2.0 with Classpath Exception** (OpenJDK): Allows linking without viral effect
3. **MIT** (Alpine packages): Permissive, allows commercial use
4. **GPL components** (bash, coreutils): Runtime dependencies, not linking

## Obtaining Source Code

### Apache Jena and Fuseki

Source code: https://jena.apache.org/download/

```bash
# Download source for version 6.0.0
wget https://downloads.apache.org/jena/source/apache-jena-6.0.0-source-release.zip
wget https://downloads.apache.org/jena/source/apache-jena-fuseki-6.0.0-source-release.zip
```

### Eclipse Temurin OpenJDK

Source code: https://github.com/adoptium/temurin-build

```bash
git clone https://github.com/adoptium/temurin-build.git
```

### Alpine Linux

Source code: https://git.alpinelinux.org/aports

```bash
# For specific packages
apk info -a <package-name>
```

### This Docker Image

Source code: https://github.com/Senticor-ai/jena-docker

```bash
git clone https://github.com/Senticor-ai/jena-docker.git
```

## SBOM (Software Bill of Materials)

For BSI TR-03183 compliance and supply chain security, we provide:

### Automated SBOM Generation

Every published image includes:
1. **SPDX SBOM** in JSON format (via Syft)
2. **In-toto Attestation** for build provenance
3. **SLSA Build Provenance** metadata

### Accessing SBOMs

```bash
# Pull and inspect attestations
docker buildx imagetools inspect \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0 --raw \
  | jq '.manifests | map(select(.annotations["vnd.docker.reference.type"] == "attestation-manifest"))'

# Using cosign (if available)
cosign verify-attestation \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0 \
  --type https://spdx.dev/Document

# Download SBOM artifact from GitHub Actions
# Go to: https://github.com/Senticor-ai/jena-docker/actions
# Select a "Publish Container Images" run
# Download the SBOM artifact
```

### Manual SBOM Generation

Generate SBOM locally:

```bash
# Using Syft
syft packages ghcr.io/senticor-ai/jena-fuseki:6.0.0 -o spdx-json > sbom.spdx.json

# Using Docker Scout
docker scout sbom ghcr.io/senticor-ai/jena-fuseki:6.0.0

# Using Trivy
trivy image --format spdx-json ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

## BSI TR-03183 Compliance

This image aims to comply with BSI Technical Guideline TR-03183 (Cyber Resilience Requirements for Manufacturers and Products):

✅ **Software Bill of Materials**: SPDX format SBOM generated and attached
✅ **Provenance**: Build provenance attestations with GitHub Actions
✅ **Vulnerability Disclosure**: Security scanning with Trivy (weekly)
✅ **License Information**: Complete license documentation (this file)
✅ **Cryptographic Signatures**: Images signed with Sigstore/cosign
✅ **Reproducible Builds**: Pinned base images and versions
✅ **Source Code Availability**: Public GitHub repository

## Commercial Use

You **may** use this image commercially under the following conditions:

1. **Apache 2.0 components** (Jena, Fuseki): Include copyright notice and license
2. **OpenJDK** (GPL-2.0 with Classpath Exception): No restrictions due to classpath exception
3. **GPL components**: Runtime use only (not linking), no restrictions

## Trademark Notice

- "Apache", "Apache Jena", and "Apache Fuseki" are trademarks of the Apache Software Foundation
- "Eclipse Temurin" is a trademark of the Eclipse Foundation
- "Alpine Linux" is a trademark of Alpine Linux Development Team
- "Docker" is a trademark of Docker, Inc.

This Docker image is **not** an official Apache Software Foundation release.

## Full License Texts

Full license texts are included in the image:

```bash
# Apache License 2.0
docker run --rm ghcr.io/senticor-ai/jena-fuseki:latest cat /jena-fuseki/LICENSE

# GPL-2.0 with Classpath Exception
docker run --rm ghcr.io/senticor-ai/jena-fuseki:latest cat /opt/java/openjdk/legal/java.base/LICENSE

# Alpine package licenses
docker run --rm ghcr.io/senticor-ai/jena-fuseki:latest cat /usr/share/licenses/
```

Online references:
- Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0
- GPL-2.0 with Classpath Exception: https://openjdk.org/legal/gplv2+ce.html
- MIT License: https://opensource.org/licenses/MIT

## Questions?

For license questions:
- Apache Jena: https://jena.apache.org/about_jena/
- This Docker image: https://github.com/Senticor-ai/jena-docker/issues

---

Last Updated: 2025-11-16
Image Version: 6.0.0

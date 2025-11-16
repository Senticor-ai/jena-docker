# Docker files for Jena

[![Build](https://github.com/Senticor-ai/jena-docker/actions/workflows/main.yml/badge.svg)](https://github.com/Senticor-ai/jena-docker/actions/workflows/main.yml)
[![Integration Tests](https://github.com/Senticor-ai/jena-docker/actions/workflows/integration-tests.yml/badge.svg)](https://github.com/Senticor-ai/jena-docker/actions/workflows/integration-tests.yml)
[![Security Scan](https://github.com/Senticor-ai/jena-docker/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Senticor-ai/jena-docker/actions/workflows/security-scan.yml)

This repository hosts [Docker](https://www.docker.com/) recipes for distributing
[Apache Jena](http://jena.apache.org/) **version 5.6.0**.

Two Docker images are available:

 - [jena](jena/) - `riot` command line and friends, for use on the command line
 - [fuseki](jena-fuseki/) - the [Fuseki](http://jena.apache.org/documentation/fuseki2/) server with SPARQL endpoint and web interface

These images are automatically published to GitHub Container Registry:

- `ghcr.io/senticor-ai/jena:5.6.0` / `ghcr.io/senticor-ai/jena:latest`
- `ghcr.io/senticor-ai/jena-fuseki:5.6.0` / `ghcr.io/senticor-ai/jena-fuseki:latest`

## Quick Start

```bash
# Run Jena riot tool
docker run --rm ghcr.io/senticor-ai/jena:5.6.0 riot --version

# Run Fuseki server
docker run -p 3030:3030 -e ADMIN_PASSWORD=yourpassword ghcr.io/senticor-ai/jena-fuseki:5.6.0

# With Podman (rootless)
podman run -p 3030:3030 -e ADMIN_PASSWORD=yourpassword ghcr.io/senticor-ai/jena-fuseki:5.6.0
```

Visit http://localhost:3030 for the Fuseki web interface.

## Features

- ✅ **Latest Apache Jena**: Version 5.6.0 with latest bug fixes and features
- ✅ **Podman Compatible**: Runs seamlessly with rootless Podman (UID 1000)
- ✅ **Multi-Architecture**: AMD64 and ARM64 support
- ✅ **Security**: Non-root user, minimal Alpine base, regular vulnerability scanning
- ✅ **Supply Chain**: SBOM (SPDX), SLSA provenance, signed attestations
- ✅ **BSI TR-03183 Compliant**: Full software supply chain security compliance
- ✅ **Production Ready**: Comprehensive integration tests, health checks

## Security & Compliance

This project includes:
- 🔒 **Weekly vulnerability scanning** with Trivy
- 📋 **Software Bill of Materials** (SBOM) in SPDX format
- 🔐 **Cryptographically signed** container images
- 📊 **SLSA Build Provenance** attestations
- 🛡️ **Security policy** with coordinated disclosure
- 📜 **Complete license documentation**

### Viewing SBOMs and Attestations

View the Software Bill of Materials and supply chain transparency information at:
**[https://senticor-ai.github.io/jena-docker/](https://senticor-ai.github.io/jena-docker/)**

SBOMs and attestations are also attached to the container images. You can access them using:

```bash
# View image attestations
docker buildx imagetools inspect ghcr.io/senticor-ai/jena-fuseki:5.6.0 --format "{{json .Attestations}}"

# Extract SBOM with Syft
syft packages ghcr.io/senticor-ai/jena-fuseki:5.6.0 -o spdx-json

# Verify build provenance with cosign
cosign verify-attestation --type slsaprovenance ghcr.io/senticor-ai/jena-fuseki:5.6.0
```

See [SECURITY.md](SECURITY.md) and [LICENSES.md](LICENSES.md) for details.

Note that although these Docker images are based on the official Apache Jena releases
and do not alter them in any way, they do **not** constitute official releases
from Apache Software Foundation.

## Publishing

Images are automatically built and published to GitHub Container Registry when changes are merged to the main branch. See [.github/PUBLISHING.md](.github/PUBLISHING.md) for details.

For local builds and publishing to other registries, see:
- [DOCKER_HUB_GUIDE.md](DOCKER_HUB_GUIDE.md) - Publishing to Docker Hub
- [PODMAN_USAGE.md](PODMAN_USAGE.md) - Using with Podman

## Building

```shell
docker build -t jena jena
docker build -t jena-fuseki jena-fuseki

# Or use the build script
./build-and-push.sh

# With Podman
podman build -t jena jena
podman build -t jena-fuseki jena-fuseki
```
 
## Dockerfile overview

The `Dockerfile`s for both images use the official [eclipse-temurin:21-jre-alpine](https://hub.docker.com/r/_/eclipse-temurin/) base image, which is based on the [`Alpine`](https://hub.docker.com/_/alpine/):3.19.1 image; this clocks in at about 62 MB.

The `ENV` variables like `JENA_VERSION` and `FUSEKI_VERSION` determines which version of Jena and Fuseki are downloaded. Updating the version also requires updating the `JENA_SHA512` and `FUSEKI_SHA512` variables, which values should match the official Jena download `.tar.gz.sha512` hashes, as approved in their release `[VOTE]` emails.

The `ASF_MIRROR` use <http://www.apache.org/dyn/mirrors/mirrors.cgi> that redirect to a local mirror, with a fallback to the `ASF_ARCHIVE` <http://archive.apache.org/dist/> for older versions.

To minimize layer size, there's a single `RUN` with `curl`, `sha512sum`, `tar zxf` and `mv` - thus the temporary files during download and extraction are not part of the final image.

Some files from the Apache Jena distributions are stripped, e.g. javadocs and the `fuseki.war` file.

The Fuseki image includes some [helper scripts](jena-fuseki/load.sh) to do [tdb loading](https://jena.apache.org/documentation/tdb/commands.html) using `fuseki-server.jar`.
In addition, Fuseki has a [`docker-entrypoint.sh`](https://github.com/Senticor-ai/jena-docker/blob/master/jena-fuseki/docker-entrypoint.sh) that populates `shiro.ini` with the password provided as `-e ADMIN_PASSWORD` to Docker, or with a new randomly generated password that is printed the first time.

**Note**: Fuseki 5.6.0 requires explicit SessionManager configuration in shiro.ini due to the migration from javax.servlet to jakarta.servlet. This is included in the image.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Documentation

- [SECURITY.md](SECURITY.md) - Security policy and best practices
- [LICENSES.md](LICENSES.md) - Complete license information
- [PODMAN_USAGE.md](PODMAN_USAGE.md) - Podman usage guide
- [DOCKER_HUB_GUIDE.md](DOCKER_HUB_GUIDE.md) - Docker Hub publishing guide
- [.github/PUBLISHING.md](.github/PUBLISHING.md) - GitHub Container Registry publishing
- [.github/ENHANCEMENTS.md](.github/ENHANCEMENTS.md) - Security and compliance features

## Support

- Apache Jena: [jena.apache.org/help_and_support/](https://jena.apache.org/help_and_support/)
- Docker Image Issues: [GitHub Issues](https://github.com/Senticor-ai/jena-docker/issues)
- Security Issues: See [SECURITY.md](SECURITY.md)

## Usage

For usage, see README for each of the Docker images:

* [jena/README.md](jena/README.md)
* [jena-fuseki/README.md](jena-fuseki/README.md)


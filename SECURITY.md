# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version / Tag Line | Supported        | Notes |
| ------------------ | ---------------- | ----- |
| Current published line (`6.0.0`, `6.0`, `6`, `latest`) | ✅ Yes | Built from the default branch and currently based on `eclipse-temurin:25-jre-alpine` |
| Historical `5.x` tags | ❌ No | Not built or patched by current CI/CD |
| Older tags | ❌ No | No active maintenance |

This repository currently publishes only the version declared in the Dockerfiles on the default branch.
At the moment that is Apache Jena/Fuseki `6.0.0`.
We do not maintain a separate `5.x` branch or publish a parallel `5.x` image line from CI.

If older `5.x` images still exist in GHCR from past publishes, treat them as historical artifacts rather than supported releases.

## Security Features

### Automated Security Scanning

- **Trivy**: Repository misconfiguration, secret, and image vulnerability scans uploaded to GitHub Security
- **Hadolint + ShellCheck**: Dockerfile and shell safety checks enforced in CI
- **Dependabot**: Alerts, automated security updates, and version updates for base images and GitHub Actions
- **Secret scanning**: GitHub secret scanning and push protection enabled on the repository
- **SBOM**: Software Bill of Materials generated for every build
- **Provenance**: Build attestations for supply chain security

### Image Security

✅ **Non-root User**: Fuseki runs as `fuseki` user (UID 1000)
✅ **Minimal Base**: Alpine Linux for small attack surface
✅ **No Secrets**: Passwords never committed, generated at runtime
✅ **Read-only FS Compatible**: Core application doesn't require write access
✅ **Pinned Versions**: Explicit version pinning for reproducibility

### Supply Chain Security

- **SLSA Level 3**: GitHub-hosted runners, provenance generation
- **Signed Images**: Sigstore attestations available
- **Immutable Tags**: Version tags never overwritten
- **Public Builds**: All builds in public GitHub Actions

## Reporting a Vulnerability

### For Apache Jena/Fuseki Vulnerabilities

Report to Apache Security Team:
- Email: security@apache.org
- More info: https://www.apache.org/security/

### For Docker Image Vulnerabilities

Report to this repository:

1. **Do NOT open a public issue**
2. Email: [Add your security contact email]
3. Or use GitHub Security Advisories:
   - Go to: https://github.com/Senticor-ai/jena-docker/security/advisories
   - Click "Report a vulnerability"

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)
- Your contact information

### Response Timeline

- **Initial Response**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix Development**: Depends on severity
  - Critical: 1-3 days
  - High: 1-2 weeks
  - Medium: 2-4 weeks
  - Low: Best effort
- **Public Disclosure**: After fix is released

## Security Best Practices

### Running the Images

#### 1. Use Specific Version Tags

```bash
# Good
docker pull ghcr.io/senticor-ai/jena-fuseki:6.0.0

# Avoid (less predictable)
docker pull ghcr.io/senticor-ai/jena-fuseki:latest
```

#### 2. Set Strong Admin Password

```bash
# Generate strong password
docker run -e ADMIN_PASSWORD=$(openssl rand -base64 32) \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

#### 3. Run as Non-Root (Podman)

```bash
# Rootless Podman (recommended)
podman run --rm -p 3030:3030 \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

#### 4. Use Read-Only Root Filesystem

```bash
docker run --read-only \
  -v fuseki-data:/fuseki \
  -v /tmp:/tmp \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

#### 5. Drop Unnecessary Capabilities

```bash
docker run --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

#### 6. Use Network Isolation

```bash
# Create isolated network
docker network create --internal fuseki-net

docker run --network fuseki-net \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

#### 7. Scan Before Deployment

```bash
# Scan with Trivy
trivy image ghcr.io/senticor-ai/jena-fuseki:6.0.0

# Scan with Docker Scout
docker scout cves ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

### Production Deployment

#### Use TLS/HTTPS

Fuseki should be behind a reverse proxy with TLS:

```yaml
# Example with Traefik
services:
  fuseki:
    image: ghcr.io/senticor-ai/jena-fuseki:6.0.0
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fuseki.rule=Host(`fuseki.example.com`)"
      - "traefik.http.routers.fuseki.entrypoints=websecure"
      - "traefik.http.routers.fuseki.tls.certresolver=letsencrypt"
```

#### Limit Resources

```bash
docker run \
  --memory="2g" \
  --cpus="2" \
  --pids-limit=100 \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

#### Configure Firewall

```bash
# Only allow specific IPs
iptables -A INPUT -p tcp --dport 3030 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 3030 -j DROP
```

## Known Security Considerations

### 1. Default Admin Password

⚠️ **Issue**: If `ADMIN_PASSWORD` is not set, a random password is generated and shown in logs.

**Mitigation**: Always set `ADMIN_PASSWORD` explicitly in production.

### 2. Shiro Configuration

ℹ️ The image uses Apache Shiro for authentication. The configuration is in `/fuseki/shiro.ini`.

**Best Practice**: Mount custom `shiro.ini` for advanced authentication setups.

### 3. JVM Memory Settings

⚠️ **Issue**: Default JVM settings may not be optimal for all environments.

**Mitigation**: Set `JVM_ARGS` appropriately:

```bash
docker run -e JVM_ARGS="-Xmx2g -Xms2g" \
  ghcr.io/senticor-ai/jena-fuseki:6.0.0
```

### 4. Data Persistence

⚠️ **Issue**: TDB databases can be corrupted if accessed concurrently.

**Mitigation**:
- Only run one Fuseki instance per database volume
- Use proper locking mechanisms
- Regular backups

## Vulnerability Disclosure Policy

We follow **Coordinated Disclosure**:

1. Vulnerability reported privately
2. We acknowledge and assess
3. We develop and test fix
4. We coordinate disclosure timing
5. Fix released, then public disclosure
6. CVE requested if applicable

## Security Updates

Subscribe to security updates:

- GitHub: Watch this repository → Custom → Security alerts
- RSS: https://github.com/Senticor-ai/jena-docker/security/advisories.atom

## Compliance

### Standards

- **CIS Docker Benchmark**: Following best practices
- **NIST SP 800-190**: Container security guidelines
- **BSI TR-03183**: Software supply chain security
- **SLSA Framework**: Build provenance and integrity

### Audit Trail

All builds are:
- Logged in GitHub Actions
- Reproducible from source
- Signed and attested
- Scannable for vulnerabilities

## Security Contacts

- **Apache Jena Security**: security@apache.org
- **Image Security**: [GitHub Security Advisories](https://github.com/Senticor-ai/jena-docker/security/advisories)
- **General Questions**: https://github.com/Senticor-ai/jena-docker/issues

---

Last Updated: 2026-04-01
Image Version: 6.0.0

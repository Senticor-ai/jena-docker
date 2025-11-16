# Contributing to Jena Docker

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Code of Conduct

Be respectful and constructive in all interactions. We're here to make better Docker images for Apache Jena.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports:
- Check the [existing issues](https://github.com/Senticor-ai/jena-docker/issues)
- Check if you're using the latest version
- Try to reproduce with a minimal example

When reporting bugs, include:
- Docker/Podman version
- Host OS and version
- Complete error messages and logs
- Steps to reproduce
- Expected vs actual behavior

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When suggesting:
- Use a clear and descriptive title
- Provide detailed description of the enhancement
- Explain why this would be useful
- Include examples if applicable

### Security Vulnerabilities

**Do NOT open public issues for security vulnerabilities!**

See [SECURITY.md](SECURITY.md) for how to report security issues.

## Development Process

### 1. Fork and Clone

```bash
git fork https://github.com/Senticor-ai/jena-docker
git clone https://github.com/YOUR-USERNAME/jena-docker
cd jena-docker
```

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

Branch naming:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation only
- `security/` - Security fixes
- `chore/` - Maintenance tasks

### 3. Make Changes

#### Testing Locally

```bash
# Build images
docker build -t jena:test jena/
docker build -t jena-fuseki:test jena-fuseki/
# Exercise both architectures (matches CI)
podman build --platform linux/amd64,linux/arm64 jena-fuseki

# Test Jena
docker run --rm jena:test riot --version

# Test Fuseki
docker run -d --name fuseki-test -p 3030:3030 -e ADMIN_PASSWORD=test123 jena-fuseki:test
sleep 10
curl -u admin:test123 http://localhost:3030/$/server
docker stop fuseki-test && docker rm fuseki-test

# Run integration tests locally (requires Docker)
cd .github/workflows
# Review integration-tests.yml and run relevant commands manually
```

> 💡 **Lesson learned:** Our GitHub Actions use Buildx/QEMU for ARM64; they regularly surface timing bugs (e.g., Fuseki taking >20 s to respond). Running the multi-arch `podman build --platform ...` command locally keeps the CI signal green and avoids long back-and-forth cycles.

#### Transparency workflow checks

When you touch SBOM generation, attestations, or documentation that feeds the transparency site:

1. Push your changes and let “Publish Container Images” finish.
2. Ensure “Publish SBOM to GitHub Pages” runs (it depends on the previous workflow).
3. Visit https://senticor-ai.github.io/jena-docker/ and confirm:
   - SBOM cards list the new artifacts.
   - Documentation links open the freshly generated HTML snapshots (no GitHub login required).
4. If workflows were skipped (e.g., docs-only changes), manually trigger them via **Actions → Run workflow**.

#### Code Style

- **Dockerfiles**:
  - Use multi-line format for RUN commands
  - One instruction per line where possible
  - Comments explain WHY, not WHAT
  - Keep layers minimal

- **Shell Scripts**:
  - Use `#!/bin/bash` shebang
  - Include Apache License header
  - Use `set -e` for error handling
  - Quote variables: `"$VAR"`
  - Use meaningful variable names

- **Documentation**:
  - Update README.md if adding features
  - Add comments for complex logic
  - Update SECURITY.md for security-related changes
  - Keep LICENSES.md accurate

### 4. Update Version Information

When upgrading Jena/Fuseki versions:

1. Update `Dockerfile`:
   ```dockerfile
   ENV JENA_VERSION 5.x.x
   ENV JENA_SHA512 <new-sha512>
   ```

2. Get SHA512 from:
   ```bash
   curl https://downloads.apache.org/jena/binaries/apache-jena-5.x.x.tar.gz.sha512
   ```

3. Update `README.md` with new version number

4. Test thoroughly before submitting

### 5. Commit Guidelines

Use conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that neither fixes bug nor adds feature
- `test`: Adding tests
- `chore`: Maintenance
- `security`: Security fix

Example:
```
fix(fuseki): add SessionManager to shiro.ini for Fuseki 5.6.0

Fuseki 5.6.0 requires explicit SessionManager configuration due to
migration from javax.servlet to jakarta.servlet. Without this,
admin endpoints fail with HTTP 500 "No SessionManager" error.

Fixes #123
```

### 6. Submit Pull Request

1. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Create Pull Request:
   - Use descriptive title
   - Reference related issues
   - Describe changes and motivation
   - Include test results
   - Add screenshots if UI changes

3. Wait for CI checks:
   - Build tests must pass
   - Integration tests must pass
   - Security scans must complete
   - No new critical vulnerabilities

4. Respond to review feedback

## Pull Request Checklist

- [ ] Code follows project style
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] Commit messages follow guidelines
- [ ] No merge conflicts
- [ ] CI checks passing
- [ ] Security scan clean (or issues justified)
- [ ] LICENSES.md updated if dependencies changed
- [ ] README.md updated if user-facing changes

## Version Upgrades

When upgrading Jena/Fuseki:

### Required Changes

1. **Dockerfiles** (`jena/Dockerfile`, `jena-fuseki/Dockerfile`):
   - Update `JENA_VERSION` / `FUSEKI_VERSION`
   - Update `JENA_SHA512` / `FUSEKI_SHA512`
   - Update comment: `# apache-jena-X.x.x.tar.gz.sha512`

2. **README.md**:
   - Update version in description
   - Update Quick Start examples

3. **Testing**:
   - Build both images
   - Run full integration test suite
   - Test basic functionality manually
   - Check for breaking changes in release notes

### SHA512 Verification

```bash
# Download SHA512 files
curl https://downloads.apache.org/jena/binaries/apache-jena-5.x.x.tar.gz.sha512
curl https://downloads.apache.org/jena/binaries/apache-jena-fuseki-5.x.x.tar.gz.sha512

# Or verify downloaded files
sha512sum apache-jena-5.x.x.tar.gz
sha512sum apache-jena-fuseki-5.x.x.tar.gz
```

### Breaking Changes

Check Apache Jena release notes for:
- Configuration changes (like Shiro SessionManager in 5.6.0)
- Deprecated features
- New required dependencies
- Java version changes
- API changes affecting scripts

## Adding Dependencies

When adding new packages to Dockerfiles:

1. Justify why it's needed
2. Use minimal/official packages
3. Update `LICENSES.md` with license info
4. Consider security implications
5. Check if increases image size significantly

## Security Considerations

- Never commit secrets or passwords
- Use explicit versions, not `latest`
- Run as non-root user
- Minimize attack surface
- Document security implications
- Update `SECURITY.md` if relevant

## Testing

### Automated Tests

All PRs must pass:
- Build tests
- Integration tests
- Security scans

### Manual Testing

Before submitting:
```bash
# Test Jena tools
docker run --rm jena:test riot --version
docker run --rm jena:test arq --help

# Test Fuseki
docker run -d -p 3030:3030 -e ADMIN_PASSWORD=test jena-fuseki:test
# Visit http://localhost:3030
# Test dataset creation
# Test data upload
# Test SPARQL queries
```

## Documentation

Good documentation includes:
- What changed
- Why it changed
- How to use new features
- Migration notes if breaking changes
- Examples

## Getting Help

- GitHub Discussions: Ask questions
- GitHub Issues: Report bugs
- Apache Jena mailing list: Jena-specific questions

## Attribution

Contributors are recognized in:
- Git commit history
- Release notes
- GitHub Contributors page

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0, the same license as this project.

---

Thank you for contributing! 🎉

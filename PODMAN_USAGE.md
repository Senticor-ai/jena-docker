# Using Jena Docker Images with Podman

This guide explains how to build and use these Apache Jena images with Podman.

## Why These Images Work Well with Podman

These images are designed with Podman compatibility in mind:
- **Explicit UID/GID (1000:1000)**: Works seamlessly with rootless Podman user namespace mapping
- **Non-root user**: Fuseki runs as user `fuseki` (UID 1000), following security best practices
- **Standard Dockerfile syntax**: No Docker-specific features

## Quick Start with Podman

### 1. Build Images Locally

```bash
# Build both images
podman build -t jena:6.0.0 jena/
podman build -t jena-fuseki:6.0.0 jena-fuseki/

# Or use the build script
CONTAINER_TOOL=podman ./build-and-push.sh
```

### 2. Run Jena Command Line Tools

```bash
# Test riot
podman run --rm jena:6.0.0 riot --version

# Process RDF files from current directory
podman run --rm -v $(pwd):/rdf:Z jena:6.0.0 riot yourfile.ttl
```

**Note**: The `:Z` suffix on volumes tells Podman to relabel the content for SELinux compatibility.

### 3. Run Fuseki Server

```bash
# Simple run (data lost on restart)
podman run -p 3030:3030 -e ADMIN_PASSWORD=admin123 jena-fuseki:6.0.0

# With persistent data
podman volume create fuseki-data
podman run -d --name fuseki \
  -p 3030:3030 \
  -e ADMIN_PASSWORD=admin123 \
  -v fuseki-data:/fuseki:Z \
  jena-fuseki:6.0.0

# Check logs
podman logs fuseki
```

### 4. Mount Host Directory for Data

```bash
# Create directory on host
mkdir -p ~/fuseki-data

# Fix permissions (Podman rootless maps UID 1000 in container)
# If your host user is UID 1000, permissions work automatically!
# Otherwise:
podman unshare chown 1000:1000 ~/fuseki-data

# Run with host directory
podman run -d --name fuseki \
  -p 3030:3030 \
  -v ~/fuseki-data:/fuseki:Z \
  jena-fuseki:6.0.0
```

## Using Podman Pods (Docker Compose Alternative)

Create a pod with Fuseki and other services:

```bash
# Create a pod
podman pod create --name jena-pod -p 3030:3030

# Run Fuseki in the pod
podman run -d --pod jena-pod \
  --name fuseki \
  -v fuseki-data:/fuseki:Z \
  jena-fuseki:6.0.0

# Add other containers to the same pod (they share network)
# podman run -d --pod jena-pod ...
```

## Publishing to Container Registries

### Docker Hub

```bash
# Login
podman login docker.io

# Tag and push
podman tag jena-fuseki:6.0.0 docker.io/yourusername/jena-fuseki:6.0.0
podman push docker.io/yourusername/jena-fuseki:6.0.0
```

### GitHub Container Registry (ghcr.io)

```bash
# Login with Personal Access Token
echo $GITHUB_TOKEN | podman login ghcr.io -u yourusername --password-stdin

# Tag and push
podman tag jena-fuseki:6.0.0 ghcr.io/yourusername/jena-fuseki:6.0.0
podman push ghcr.io/yourusername/jena-fuseki:6.0.0
```

### Quay.io

```bash
# Login
podman login quay.io

# Tag and push
podman tag jena-fuseki:6.0.0 quay.io/yourusername/jena-fuseki:6.0.0
podman push quay.io/yourusername/jena-fuseki:6.0.0
```

## Systemd Integration (Podman Specific)

Run Fuseki as a systemd service:

```bash
# Generate systemd unit file
podman run -d --name fuseki \
  -p 3030:3030 \
  -v fuseki-data:/fuseki:Z \
  jena-fuseki:6.0.0

podman generate systemd --new --files --name fuseki

# Install and enable service
mkdir -p ~/.config/systemd/user/
mv container-fuseki.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now container-fuseki.service

# Check status
systemctl --user status container-fuseki.service
```

## Podman Compose

If you prefer docker-compose syntax, install podman-compose:

```bash
pip install podman-compose
```

Create `docker-compose.yml`:

```yaml
version: '3'
services:
  fuseki:
    build: ./jena-fuseki
    ports:
      - "3030:3030"
    environment:
      - ADMIN_PASSWORD=admin123
      - TDB=2
    volumes:
      - fuseki-data:/fuseki
    restart: unless-stopped

volumes:
  fuseki-data:
```

Run with:
```bash
podman-compose up -d
```

## Differences from Docker

1. **Volume mounting**: Use `:Z` for SELinux relabeling
2. **User namespaces**: UID 1000 in container maps to your host UID in rootless mode
3. **No daemon**: Podman is daemonless, containers are child processes
4. **Systemd integration**: Native support for running containers as systemd services
5. **Pods**: Podman has pods (groups of containers sharing resources)

## Troubleshooting

### Permission Denied on Volumes

```bash
# Check ownership
ls -la ~/fuseki-data

# Fix with podman unshare
podman unshare chown -R 1000:1000 ~/fuseki-data
```

### SELinux Issues

```bash
# Add :Z to volume mounts
-v ~/fuseki-data:/fuseki:Z

# Or set SELinux context manually
chcon -Rt svirt_sandbox_file_t ~/fuseki-data
```

### Port Already in Use

```bash
# Check what's using the port
sudo ss -tulpn | grep 3030

# Use a different port
podman run -p 8080:3030 jena-fuseki:6.0.0
```

## Resources

- [Podman Documentation](https://docs.podman.io/)
- [Podman vs Docker](https://docs.podman.io/en/latest/markdown/podman.1.html)
- [Rootless Containers](https://docs.podman.io/en/latest/markdown/podman-run.1.html#rootless-mode)

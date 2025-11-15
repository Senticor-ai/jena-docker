# Publishing to Docker Hub

This guide explains how to build and publish these images to Docker Hub.

## Prerequisites

1. **Docker Hub account**: Sign up at https://hub.docker.com
2. **Docker or Podman** installed locally
3. **Repository access**: Either:
   - Use your personal namespace: `yourusername/jena-fuseki`
   - Create an organization: `yourorg/jena-fuseki`

## Step-by-Step Guide

### 1. Login to Docker Hub

```bash
# With Docker
docker login

# With Podman
podman login docker.io
```

Enter your Docker Hub username and password when prompted.

### 2. Build the Images

```bash
# Set your Docker Hub username
export DOCKER_USERNAME=yourusername

# Build Jena
docker build -t $DOCKER_USERNAME/jena:5.6.0 jena/
docker tag $DOCKER_USERNAME/jena:5.6.0 $DOCKER_USERNAME/jena:latest

# Build Jena Fuseki
docker build -t $DOCKER_USERNAME/jena-fuseki:5.6.0 jena-fuseki/
docker tag $DOCKER_USERNAME/jena-fuseki:5.6.0 $DOCKER_USERNAME/jena-fuseki:latest
```

### 3. Test Locally

```bash
# Test Jena
docker run --rm $DOCKER_USERNAME/jena:5.6.0 riot --version

# Test Fuseki
docker run --rm -p 3030:3030 $DOCKER_USERNAME/jena-fuseki:5.6.0
# Visit http://localhost:3030 in your browser
# Ctrl+C to stop
```

### 4. Push to Docker Hub

```bash
# Push Jena images
docker push $DOCKER_USERNAME/jena:5.6.0
docker push $DOCKER_USERNAME/jena:latest

# Push Fuseki images
docker push $DOCKER_USERNAME/jena-fuseki:5.6.0
docker push $DOCKER_USERNAME/jena-fuseki:latest
```

### 5. Verify on Docker Hub

Visit your repositories:
- `https://hub.docker.com/r/$DOCKER_USERNAME/jena`
- `https://hub.docker.com/r/$DOCKER_USERNAME/jena-fuseki`

## Using the Automated Build Script

We've included a helper script:

```bash
# Edit the script to uncomment the push section
nano build-and-push.sh

# Run it
DOCKER_USERNAME=yourusername ./build-and-push.sh

# Or with Podman
CONTAINER_TOOL=podman DOCKER_USERNAME=yourusername ./build-and-push.sh
```

## Multi-Architecture Builds

To build for multiple platforms (AMD64, ARM64):

### Using Docker Buildx

```bash
# Create a builder
docker buildx create --name multiarch --use

# Build and push for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $DOCKER_USERNAME/jena-fuseki:5.6.0 \
  -t $DOCKER_USERNAME/jena-fuseki:latest \
  --push \
  jena-fuseki/
```

### Using Podman

```bash
# Build for AMD64
podman build --platform linux/amd64 \
  -t $DOCKER_USERNAME/jena-fuseki:5.6.0-amd64 jena-fuseki/

# Build for ARM64
podman build --platform linux/arm64 \
  -t $DOCKER_USERNAME/jena-fuseki:5.6.0-arm64 jena-fuseki/

# Create and push manifest
podman manifest create $DOCKER_USERNAME/jena-fuseki:5.6.0
podman manifest add $DOCKER_USERNAME/jena-fuseki:5.6.0 \
  $DOCKER_USERNAME/jena-fuseki:5.6.0-amd64
podman manifest add $DOCKER_USERNAME/jena-fuseki:5.6.0 \
  $DOCKER_USERNAME/jena-fuseki:5.6.0-arm64
podman manifest push $DOCKER_USERNAME/jena-fuseki:5.6.0
```

## Automated Builds with GitHub Actions

You can set up automated builds when you push to GitHub:

```yaml
# .github/workflows/docker-publish.yml
name: Publish Docker Images

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  release:
    types: [ published ]

jobs:
  push_to_registry:
    name: Push Docker image to Docker Hub
    runs-on: ubuntu-latest
    steps:
      - name: Check out the repo
        uses: actions/checkout@v4

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.DOCKER_USERNAME }}/jena-fuseki

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ./jena-fuseki
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

Add secrets to your GitHub repository:
- `Settings` → `Secrets and variables` → `Actions`
- Add `DOCKER_USERNAME` and `DOCKER_PASSWORD`

## Alternative: GitHub Container Registry (GHCR)

GitHub offers free container hosting:

```bash
# Login with Personal Access Token
echo $GITHUB_TOKEN | docker login ghcr.io -u yourusername --password-stdin

# Build and tag
docker build -t ghcr.io/yourusername/jena-fuseki:5.6.0 jena-fuseki/
docker tag ghcr.io/yourusername/jena-fuseki:5.6.0 ghcr.io/yourusername/jena-fuseki:latest

# Push
docker push ghcr.io/yourusername/jena-fuseki:5.6.0
docker push ghcr.io/yourusername/jena-fuseki:latest

# Make public (in GitHub UI)
# Go to package settings and change visibility
```

## Best Practices

1. **Version Tags**: Always tag with version number (5.6.0) and latest
2. **README**: Add a good README to your Docker Hub repository
3. **Automated Builds**: Use GitHub Actions for consistency
4. **Security Scanning**: Enable Docker Hub's security scanning
5. **Multi-arch**: Build for both AMD64 and ARM64 when possible

## Quick Reference

```bash
# One-liner to build and push everything
DOCKER_USERNAME=yourusername && \
docker login && \
docker build -t $DOCKER_USERNAME/jena:5.6.0 jena/ && \
docker build -t $DOCKER_USERNAME/jena-fuseki:5.6.0 jena-fuseki/ && \
docker tag $DOCKER_USERNAME/jena:5.6.0 $DOCKER_USERNAME/jena:latest && \
docker tag $DOCKER_USERNAME/jena-fuseki:5.6.0 $DOCKER_USERNAME/jena-fuseki:latest && \
docker push $DOCKER_USERNAME/jena:5.6.0 && \
docker push $DOCKER_USERNAME/jena:latest && \
docker push $DOCKER_USERNAME/jena-fuseki:5.6.0 && \
docker push $DOCKER_USERNAME/jena-fuseki:latest
```

## Users Can Then Pull Your Images

```bash
# Pull and run
docker pull yourusername/jena-fuseki:5.6.0
docker run -p 3030:3030 yourusername/jena-fuseki:5.6.0

# Or with Podman
podman pull docker.io/yourusername/jena-fuseki:5.6.0
podman run -p 3030:3030 yourusername/jena-fuseki:5.6.0
```

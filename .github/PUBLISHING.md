# Publishing Container Images

This repository has automated GitHub Actions workflows to publish container images.

## GitHub Container Registry (GHCR) - Automatic ✅

Images are **automatically published** to GitHub Container Registry when you:
- Push to `main` or `master` branch
- Create a release
- Create a version tag (e.g., `v6.0.0`)
- Manually trigger the workflow

### Published Images

After the workflow runs, images will be available at:
- `ghcr.io/<owner>/jena:latest`
- `ghcr.io/<owner>/jena:6.0.0`
- `ghcr.io/<owner>/jena-fuseki:latest`
- `ghcr.io/<owner>/jena-fuseki:6.0.0`

The workflow now derives `<owner>` from the repository owner automatically and normalizes it to lowercase for GHCR compatibility.

### Using the Images

```bash
# Pull and run with Docker
docker pull ghcr.io/<owner>/jena-fuseki:latest
docker run -p 3030:3030 ghcr.io/<owner>/jena-fuseki:latest

# Pull and run with Podman
podman pull ghcr.io/<owner>/jena-fuseki:latest
podman run -p 3030:3030 ghcr.io/<owner>/jena-fuseki:latest
```

### Making Images Public

By default, GHCR images are private. To make them public:

1. Go to your GitHub profile → Packages
2. Find the `jena` or `jena-fuseki` package
3. Click "Package settings"
4. Scroll to "Danger Zone"
5. Click "Change visibility" → "Public"

## Docker Hub Publishing - Manual 🔧

The Docker Hub workflow is **disabled by default** (manual trigger only).

### Setup for Docker Hub

If you want to publish to Docker Hub:

1. **Create Docker Hub Access Token**
   - Go to https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Give it a name and copy the token

2. **Add Secrets to GitHub Repository**
   - Go to your repository → Settings → Secrets and variables → Actions
   - Add two secrets:
     - `DOCKERHUB_USERNAME`: Your Docker Hub username
     - `DOCKERHUB_TOKEN`: The access token you created

3. **Enable Automatic Publishing** (Optional)
   - Edit `.github/workflows/publish-dockerhub.yml`
   - Uncomment the `on:` triggers (push, release, etc.)
   - Commit and push the changes

4. **Manual Trigger**
   - Go to Actions → "Publish to Docker Hub"
   - Click "Run workflow"

## Multi-Architecture Support

Both workflows build for:
- `linux/amd64` (Intel/AMD)
- `linux/arm64` (ARM, Apple Silicon, Raspberry Pi)

The correct architecture is automatically selected when you pull the image.

## Version Tags

The workflows automatically create these tags:
- `latest` - Latest build from main/master branch
- `6.0.0` - Specific version
- `6.0` - Major.minor version
- `6` - Major version
- `main-<sha>` - Branch name with git SHA
- `v6.0.0` - If you push a git tag like `v6.0.0`

## Workflow Files

- `.github/workflows/main.yml` - Build and test (runs on all PRs/pushes)
- `.github/workflows/publish.yml` - Publish to GHCR (automatic)
- `.github/workflows/publish-dockerhub.yml` - Publish to Docker Hub (manual)

## Triggering a Release

### Method 1: Push a Tag

```bash
git tag v6.0.0
git push origin v6.0.0
```

This will trigger both build and publish workflows.

### Method 2: Create a GitHub Release

1. Go to your repository → Releases
2. Click "Draft a new release"
3. Create a new tag (e.g., `v6.0.0`)
4. Fill in release notes
5. Click "Publish release"

This will trigger the publish workflow and create versioned images.

### Method 3: Manual Trigger

1. Go to Actions tab
2. Select "Publish Container Images"
3. Click "Run workflow"
4. Choose the branch
5. Click "Run workflow"

## Checking Build Status

- Go to the Actions tab in your repository
- Click on the workflow run to see logs
- Green checkmark ✓ = Success
- Red X ✗ = Failed (click to see error logs)

## Cache

The workflows use GitHub Actions cache to speed up builds:
- Docker layer caching
- Faster subsequent builds
- Automatic cache management

## Security

- Uses `GITHUB_TOKEN` for GHCR (automatically provided by GitHub)
- Requires explicit secrets for Docker Hub
- Smoke-tests each image before publishing
- Builds are isolated in GitHub's infrastructure
- SBOM and provenance attestations generated (GHCR only)

## Troubleshooting

### "Permission denied" when pushing to GHCR

Make sure the workflow has `packages: write` permission. This should already be set in the workflow file.

### Images not showing up

1. Check the Actions tab for failed workflows
2. Make images public in Package settings
3. Verify you're using the correct image name format

### Docker Hub push fails

1. Verify `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets are set
2. Check the token hasn't expired
3. Ensure you have permission to push to that Docker Hub repository

## Local Testing

To test the build locally before pushing:

```bash
# Using Docker
docker buildx build --platform linux/amd64,linux/arm64 -t test/jena:latest jena/

# Using the build script
./build-and-push.sh
```

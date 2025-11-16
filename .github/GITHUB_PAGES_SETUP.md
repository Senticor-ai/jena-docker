# GitHub Pages Setup Guide

This repository includes an automated GitHub Pages deployment for SBOM transparency.

## What Gets Published

A professional, human-readable webpage at `https://senticor-ai.github.io/jena-docker/` that includes:

- 📋 Downloadable SBOM files in SPDX format
- 🔍 Instructions for accessing container image attestations
- 🐳 Container image information
- 🛡️ Security features and compliance information
- 📚 Links to documentation and policies
- ✅ BSI TR-03183, SLSA, and SPDX compliance badges

## Enable GitHub Pages

**One-time setup required:**

1. Navigate to repository settings:
   ```
   https://github.com/Senticor-ai/jena-docker/settings/pages
   ```

2. Under **"Build and deployment"** section:
   - **Source**: Select **"GitHub Actions"**
   - (Do NOT use "Deploy from a branch")

3. Click **Save**

## How It Works

1. **Automatic Deployment**
   - Triggered automatically after the "Publish Container Images" workflow completes
   - Runs on every push to `main`/`master` branch
   - Downloads SBOM artifacts from the build workflow
   - Generates a beautiful HTML page
   - Deploys to GitHub Pages

2. **Manual Deployment**
   - Go to Actions tab
   - Select "Publish SBOM to GitHub Pages" workflow
   - Click "Run workflow"
   - Choose branch and run

## Viewing the Page

Once enabled, your page will be available at:
```
https://senticor-ai.github.io/jena-docker/
```

The page automatically updates with each new container image release.

## Workflow File

The GitHub Pages deployment is configured in:
```
.github/workflows/publish-sbom-pages.yml
```

## Troubleshooting

**Page not appearing?**
- Verify GitHub Pages is enabled in repository settings
- Check that Source is set to "GitHub Actions" (not branch)
- Look at Actions tab for workflow run status
- First deployment may take a few minutes

**SBOMs not showing?**
- SBOMs are generated during the "Publish Container Images" workflow
- Ensure that workflow has run successfully at least once
- The Pages workflow runs after the publish workflow completes

## Features

- ✅ Professional, responsive design
- ✅ Dark code blocks for command examples
- ✅ Compliance badges (BSI TR-03183, SLSA Level 3, SPDX 2.3)
- ✅ Downloadable SBOM files
- ✅ Container verification instructions
- ✅ Links to all documentation
- ✅ Automatic timestamp updates

## Compliance

This implementation satisfies:
- **BSI TR-03183** transparency requirements
- **SLSA** provenance disclosure guidelines
- **SPDX** SBOM publication best practices
- **OpenSSF** supply chain security recommendations

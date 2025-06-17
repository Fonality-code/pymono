# Docker Build and Publish Workflows

This repository contains GitHub Actions workflows to automatically build and publish Docker images to GitHub Container Registry (ghcr.io) for each app in the monorepo.

## Workflows

### 1. Automatic Build and Publish (`docker-build-publish.yml`)

This workflow automatically triggers on:
- **Push to `main` or `develop` branches**: Builds only apps that have changed (or all apps if `shared` package changed)
- **Pull Requests to `main`**: Builds changed apps for validation (without publishing)
- **Releases**: Builds and publishes all apps with release tags

#### Features:
- 🔍 **Smart Change Detection**: Only builds apps that have actually changed
- 🏗️ **Multi-platform builds**: Supports both `linux/amd64` and `linux/arm64`
- 🏷️ **Automatic Tagging**: Uses semantic versioning and branch-based tags
- 🔒 **Security Scanning**: Includes Trivy vulnerability scanning
- 📋 **Build Attestation**: Generates SLSA build provenance
- ⚡ **Caching**: Uses GitHub Actions cache for faster builds

#### Image Tags Generated:
- `latest` (for main branch)
- `develop` (for develop branch)
- `pr-123` (for pull requests)
- `v1.2.3`, `v1.2`, `v1` (for releases)
- `main-sha123456` (commit SHA)

### 2. Manual Build and Publish (`manual-docker-build.yml`)

This workflow can be triggered manually from the GitHub Actions tab.

#### Inputs:
- **App**: Specific app to build (leave empty to build all apps)
- **Tag**: Custom tag for the image (default: "manual")

## Image Registry

Images are published to GitHub Container Registry at:
```
ghcr.io/YOUR_USERNAME/pymono/APP_NAME:TAG
```

For example:
```
ghcr.io/YOUR_USERNAME/pymono/api:latest
ghcr.io/YOUR_USERNAME/pymono/api:v1.0.0
ghcr.io/YOUR_USERNAME/pymono/api:develop
```

## Using the Images

### Pull from GitHub Container Registry

1. **Authenticate with GitHub Container Registry:**
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
   ```

2. **Pull and run an image:**
   ```bash
   # Pull latest from main branch
   docker pull ghcr.io/YOUR_USERNAME/pymono/api:latest

   # Run the container
   docker run -p 8080:8000 ghcr.io/YOUR_USERNAME/pymono/api:latest
   ```

### Update docker-compose.yaml

Update your `docker-compose.yaml` to use the published images:

```yaml
services:
  api:
    image: ghcr.io/YOUR_USERNAME/pymono/api:latest
    # Remove the build section when using published images
    container_name: mono-api
    ports:
      - "8080:8000"
    # ... rest of your configuration
```

## Setting Up Permissions

### Repository Settings

1. Go to your repository **Settings** → **Actions** → **General**
2. Under "Workflow permissions", select **Read and write permissions**
3. Check **Allow GitHub Actions to create and approve pull requests**

### Package Visibility

1. Go to your repository **Packages** tab
2. Click on a published package
3. Go to **Package settings**
4. Set visibility to **Public** if you want the images to be publicly accessible

## Adding New Apps

When you add a new app to the `apps/` directory:

1. **Create a Dockerfile** in `apps/your-new-app/Dockerfile`
2. **Follow the same pattern** as the existing API Dockerfile
3. **The workflow will automatically detect** the new app and include it in builds

Example structure:
```
apps/
  your-new-app/
    Dockerfile          # Required for auto-detection
    pyproject.toml
    main.py
    # ... other files
```

## Troubleshooting

### Common Issues:

1. **Permission denied when pushing to registry**
   - Ensure the repository has proper permissions set
   - Check that `GITHUB_TOKEN` has package write permissions

2. **Docker build fails**
   - Check that all paths in Dockerfile are correct
   - Ensure dependencies are properly defined in pyproject.toml

3. **No apps detected for build**
   - Ensure your app has a Dockerfile in `apps/APP_NAME/Dockerfile`
   - Check that file changes are in the expected paths

### Debugging:

You can check the workflow logs in the **Actions** tab of your repository to see:
- Which apps were detected for building
- Build progress and any errors
- Published image details

## Security

- 🛡️ **Vulnerability Scanning**: All images are automatically scanned with Trivy
- 🔐 **Build Attestation**: SLSA provenance is generated for all builds
- 🔒 **Minimal Permissions**: Workflows use least-privilege access
- 📋 **Audit Trail**: All builds are logged and traceable

## Manual Workflow Usage

To manually trigger a build:

1. Go to **Actions** tab in your repository
2. Select **Manual Docker Build and Publish**
3. Click **Run workflow**
4. Choose the app to build (or leave empty for all)
5. Optionally specify a custom tag

This is useful for:
- Testing new Dockerfiles
- Creating custom tagged images
- Building specific apps without pushing code changes

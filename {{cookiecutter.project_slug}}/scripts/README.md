# Docker Registry Push Scripts

This directory contains scripts for pushing Docker images to different container registries. These scripts can be used both locally and in GitHub workflows.

## Scripts

### 1. `prepare-deployment.sh` - Prepare deployment with version management
### 2. `push-to-quay.sh` - Push to Quay.io
### 3. `push-to-ghcr.sh` - Push to GitHub Container Registry (GHCR)

## Prerequisites

- Docker installed and running
- Git repository (for SHA tagging)
- Valid credentials for the target registry

### For Deployment Preparation

- Git installed and configured
- Access to configured repositories
- GitHub token with appropriate permissions (for pushing version updates)

## Repository Configuration

The `prepare-deployment.sh` script now supports dynamic repository configuration instead of hardcoded frontend/backend repos. You can configure repositories in two ways:

### Method 1: Using repos.config file (Recommended)

Create a `repos.config` file in the project root with the following format:

```
# Repository Configuration
# Format: repo_name=repository_url
frontend=https://github.com/your-org/frontend-repo.git
backend=https://github.com/your-org/backend-repo.git
api=https://github.com/your-org/api-service.git
mobile=https://github.com/your-org/mobile-app.git
```

### Method 2: Using Environment Variables

Set environment variables with the pattern `*_REPO_URL`:

```bash
export FRONTEND_REPO_URL="https://github.com/your-org/frontend-repo.git"
export BACKEND_REPO_URL="https://github.com/your-org/backend-repo.git"
export API_REPO_URL="https://github.com/your-org/api-service.git"
```

### Backward Compatibility

For backward compatibility, if no configuration is found, the script will fall back to the original `FRONTEND_REPO_URL` and `BACKEND_REPO_URL` environment variables.

## Certificate Installation

The deployment scripts support automatic installation of certificates into Docker images. This is useful when your applications need to trust custom Certificate Authorities or internal certificates.

### Configuration

Certificate installation is configured in the `deploy.config` file:

```
# Certificate configuration
cert_install_path=/usr/local/share/ca-certificates

# Repository mappings with certificate flags
frontend_image=https://github.com/your-org/frontend.git
frontend_image_needs_certs=false
backend_image=https://github.com/your-org/backend.git
backend_image_needs_certs=true
```

### Certificate Files

Place your certificate files in the `assets/` directory:

```
assets/
├── company-root-ca.crt
├── intermediate-ca.pem
└── custom-cert.cer
```

Supported certificate formats:
- `.crt` - Certificate files
- `.pem` - PEM encoded certificates
- `.cer` - Certificate files

### How It Works

When a repository is flagged with `{image_name}_needs_certs=true`:

1. The Docker image is built normally using the project's Dockerfile
2. A temporary Dockerfile is created that:
   - Uses the built image as the base
   - Installs the `ca-certificates` package (if not present)
   - Copies all certificate files from `assets/` to the configured path
   - Runs `update-ca-certificates` to install the certificates
3. The image is re-tagged with the original tags
4. The image with certificates is pushed to the registry

### Template Variables

When using with cookiecutter, configure these variables:

- `images_need_certs`: Comma-separated boolean values (e.g., "false,true,false")
- `cert_install_path`: Path where certificates should be installed (default: "/usr/local/share/ca-certificates")

### Example Usage

```bash
# Deploy with automatic certificate installation
./scripts/deploy-all.sh

# Push individual image with certificates
./scripts/push-to-ghcr.sh -i backend_image

# The scripts will automatically detect if certificates are needed
# and install them from the assets/ directory
```

### Supported Base Images

The certificate installation works with:
- Debian/Ubuntu based images (uses `apt-get` and `update-ca-certificates`)
- Alpine Linux images (uses `apk` and `update-ca-certificates`)
- RHEL/CentOS images (uses `yum` and `update-ca-trust`)

## Supported Project Types

The script automatically detects and handles various project types:

- **Node.js/JavaScript**: Detects `package.json`
- **Python**: Detects `pyproject.toml`, `requirements.txt`, or `setup.py`
- **Go**: Detects `go.mod`
- **Java/Maven**: Detects `pom.xml`
- **Java/Gradle**: Detects `build.gradle` or `build.gradle.kts`
- **.NET**: Detects `*.csproj` or `*.sln`
- **Docker**: Detects `Dockerfile` and `docker-compose.yml`

## Quick Setup

### Environment Configuration

Create a `.env` file in your project root to configure repository URLs:

```bash
# .env file
FRONTEND_REPO_URL=https://github.com/your-org/textmate-frontend.git
BACKEND_REPO_URL=https://github.com/your-org/textmate-backend.git
GITHUB_TOKEN=ghp_xxxxxxxxxxxx  # Optional for deployment preparation
```

### Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### Test Your Setup

```bash
# Test deployment preparation without making changes
./scripts/prepare-deployment.sh patch --test

# Test Docker registry connections
./scripts/push-to-ghcr.sh -i test-image --dry-run
./scripts/push-to-quay.sh -i test-image --dry-run
```

## Local Usage

### Prepare Deployment

The `prepare-deployment.sh` script automates the deployment preparation process by:
- Managing semantic versioning
- Cloning frontend and backend repositories
- Preparing projects for Docker builds
- Updating changelogs
- Creating GitHub release notes

```bash
# Basic usage - patch version bump (1.0.0 -> 1.0.1)
./scripts/prepare-deployment.sh

# Minor version bump (1.0.1 -> 1.1.0)
./scripts/prepare-deployment.sh minor

# Major version bump (1.1.0 -> 2.0.0)
./scripts/prepare-deployment.sh major

# Test mode (no commits, see what would happen)
./scripts/prepare-deployment.sh patch --test
./scripts/prepare-deployment.sh minor --no-commit
```

### Push to Quay.io

```bash
# Set environment variables
export QUAY_USER=your-username
export QUAY_PASSWORD=your-password-or-token
export IMAGE_NAME=textmate-backend

# Run the script
./scripts/push-to-quay.sh

# Or with command line arguments
./scripts/push-to-quay.sh -i textmate-backend -u your-username -p your-token

# With organization and team
./scripts/push-to-quay.sh -i textmate-backend -o myorg -t myteam -u your-username -p your-token
```

### Push to GHCR

```bash
# Set environment variables
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export IMAGE_NAME=textmate-backend

# Run the script (repository owner auto-detected from git remote)
./scripts/push-to-ghcr.sh

# Or with command line arguments
./scripts/push-to-ghcr.sh -i textmate-backend -t ghp_xxxxxxxxxxxx -o your-username
```

## GitHub Workflow Usage

### Example workflow step for deployment preparation

```yaml
- name: Prepare Deployment
  run: ./scripts/prepare-deployment.sh patch
  env:
    FRONTEND_REPO_URL: https://github.com/${{ github.repository_owner }}/textmate-frontend.git
    BACKEND_REPO_URL: https://github.com/${{ github.repository_owner }}/textmate-backend.git
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Create Release
  uses: actions/create-release@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    tag_name: v${{ steps.version.outputs.version }}
    release_name: Release v${{ steps.version.outputs.version }}
    body_path: release_changelog.md
    draft: false
    prerelease: false
```

### Complete deployment workflow example

```yaml
name: Deploy Application

on:
  workflow_dispatch:
    inputs:
      version_bump:
        description: 'Version bump type'
        required: true
        default: 'patch'
        type: choice
        options:
          - patch
          - minor
          - major

jobs:
  prepare-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Prepare Deployment
        id: prepare
        run: ./scripts/prepare-deployment.sh ${{ github.event.inputs.version_bump }}
        env:
          FRONTEND_REPO_URL: https://github.com/${{ github.repository_owner }}/textmate-frontend.git
          BACKEND_REPO_URL: https://github.com/${{ github.repository_owner }}/textmate-backend.git
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Build and Push Frontend
        run: ./scripts/push-to-ghcr.sh -i textmate-frontend
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Build and Push Backend
        run: ./scripts/push-to-quay.sh -i textmate-backend
        env:
          QUAY_USER: ${{ secrets.QUAY_USER }}
          QUAY_PASSWORD: ${{ secrets.QUAY_PASSWORD }}
          
      - name: Read Version
        id: version
        run: echo "version=$(cat version.txt)" >> $GITHUB_OUTPUT
        
      - name: Create Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: v${{ steps.version.outputs.version }}
          release_name: Release v${{ steps.version.outputs.version }}
          body_path: release_changelog.md
          draft: false
          prerelease: false
```

### Example workflow step for Quay.io

```yaml
- name: Push to Quay.io
  run: ./scripts/push-to-quay.sh
  env:
    QUAY_USER: ${{ secrets.QUAY_USER }}
    QUAY_PASSWORD: ${{ secrets.QUAY_PASSWORD }}
    IMAGE_NAME: textmate-backend
    QUAY_ORGANIZATION: ${{ vars.QUAY_ORGANIZATION }}
    ADDITIONAL_TAG: ${{ github.ref_name }}
```

### Example workflow step for GHCR

```yaml
- name: Push to GHCR
  run: ./scripts/push-to-ghcr.sh
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    IMAGE_NAME: textmate-backend
    ADDITIONAL_TAG: ${{ github.ref_name }}
```

## Environment Variables

### Quay.io Script (`push-to-quay.sh`)

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `QUAY_USER` | ✅ | Quay.io username | |
| `QUAY_PASSWORD` | ✅ | Quay.io password or robot token | |
| `IMAGE_NAME` | ✅ | Base image name | |
| `QUAY_ORGANIZATION` | ❌ | Quay organization name | |
| `QUAY_TEAM` | ❌ | Quay team name | |
| `ADDITIONAL_TAG` | ❌ | Additional custom tag | |
| `DOCKERFILE_PATH` | ❌ | Path to Dockerfile | `Dockerfile` |
| `WORKING_DIR` | ❌ | Working directory | `.` |
| `SHA_TAG` | ❌ | Enable SHA-based tag | `true` |

### GHCR Script (`push-to-ghcr.sh`)

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `GITHUB_TOKEN` | ✅ | GitHub personal access token | |
| `IMAGE_NAME` | ✅ | Base image name | |
| `GITHUB_REPOSITORY_OWNER` | ❌ | Repository owner (auto-detected) | |
| `GITHUB_ACTOR` | ❌ | GitHub username | |
| `ADDITIONAL_TAG` | ❌ | Additional custom tag | |
| `DOCKERFILE_PATH` | ❌ | Path to Dockerfile | `Dockerfile` |
| `WORKING_DIR` | ❌ | Working directory | `.` |
| `SHA_TAG` | ❌ | Enable SHA-based tag | `true` |

### Deployment Preparation Script (`prepare-deployment.sh`)

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `FRONTEND_REPO_URL` | ❌ | Frontend repository URL | `https://github.com/your-org/frontend-repo.git` |
| `BACKEND_REPO_URL` | ❌ | Backend repository URL | `https://github.com/your-org/backend-repo.git` |
| `GITHUB_TOKEN` | ❌ | GitHub token for pushing changes | |

### Certificate Installation

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `CERT_INSTALL_PATH` | ❌ | Path where certificates are installed in images | `/usr/local/share/ca-certificates` |
| `{IMAGE_NAME}_NEEDS_CERTS` | ❌ | Whether image needs certificate installation | `false` |

## Command Line Options

### Deployment Preparation Script (`prepare-deployment.sh`)

```bash
./prepare-deployment.sh [patch|minor|major] [--test|--no-commit]
```

- First argument: Version bump type
  - `patch` - Increment patch version (1.0.0 → 1.0.1)
  - `minor` - Increment minor version (1.0.1 → 1.1.0)  
  - `major` - Increment major version (1.1.0 → 2.0.0)
- Second argument (optional): Mode flag
  - `--test` or `--no-commit` - Run in test mode (no commits, no pushes)

### Docker Push Scripts

Both `push-to-quay.sh` and `push-to-ghcr.sh` support the following common options:

- `-h, --help` - Show help message
- `-i, --image-name` - Image name (required)
- `-d, --dockerfile` - Dockerfile path
- `-w, --working-dir` - Working directory
- `--additional-tag` - Additional custom tag
- `--no-sha-tag` - Disable SHA-based tagging
- `--dry-run` - Show what would be done without executing

### Quay.io specific options:
- `-o, --organization` - Quay organization
- `-t, --team` - Quay team
- `-u, --user` - Quay username
- `-p, --password` - Quay password/token

### GHCR specific options:
- `-o, --owner` - Repository owner
- `-u, --user` - GitHub username
- `-t, --token` - GitHub token

## Examples

### Local Development

```bash
# Deployment preparation examples
# Test what would happen with a patch version bump
./scripts/prepare-deployment.sh patch --test

# Perform actual patch version bump (1.0.0 -> 1.0.1)
./scripts/prepare-deployment.sh patch

# Minor version bump (1.0.1 -> 1.1.0)
./scripts/prepare-deployment.sh minor

# Major version bump (1.1.0 -> 2.0.0)
./scripts/prepare-deployment.sh major

# Docker push examples
# Push backend to Quay.io
cd backend
export QUAY_USER=myuser
export QUAY_PASSWORD=mytoken
../scripts/push-to-quay.sh -i textmate-backend

# Push frontend to GHCR
cd frontend
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
../scripts/push-to-ghcr.sh -i textmate-frontend

# Dry run to see what would happen
./scripts/push-to-ghcr.sh -i textmate-backend --dry-run
```

### Deployment Preparation Workflow

```bash
# 1. Configure repository URLs (optional - can use defaults)
export FRONTEND_REPO_URL="https://github.com/your-org/textmate-frontend.git"
export BACKEND_REPO_URL="https://github.com/your-org/textmate-backend.git"
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

# 2. Test the deployment preparation (recommended first)
./scripts/prepare-deployment.sh patch --test

# 3. Perform actual deployment preparation
./scripts/prepare-deployment.sh patch

# 4. Build and push Docker images
./scripts/push-to-ghcr.sh -i textmate-frontend
./scripts/push-to-quay.sh -i textmate-backend
```

### With Custom Tags

```bash
# Add a version tag
./scripts/push-to-ghcr.sh -i textmate-backend --additional-tag v1.2.3

# Disable SHA tagging
./scripts/push-to-quay.sh -i textmate-backend --no-sha-tag
```

## Files Created by Scripts

### Deployment Preparation Script

The `prepare-deployment.sh` script creates and modifies several files:

1. **`version.txt`** - Contains the current version number (e.g., `1.2.3`)
2. **`README.md`** - Updated with changelog entries including:
   - Version information and timestamp
   - Frontend and backend commit details with links
   - Repository information
3. **`release_changelog.md`** - Generated release notes for GitHub releases
4. **`frontend/` and `backend/`** - Cloned repositories ready for Docker builds

### Example generated changelog entry in README.md

```markdown
### Version 1.2.3 - 2025-06-20 14:30:15

- **Version**: 1.2.3
- **Type**: patch version bump

#### Frontend Repository
- **Commit**: [`a1b2c3d4`](https://github.com/your-org/frontend-repo/commit/a1b2c3d4...)
- **Message**: Fix responsive design issues

#### Backend Repository
- **Commit**: [`e5f6g7h8`](https://github.com/your-org/backend-repo/commit/e5f6g7h8...)
- **Message**: Improve API performance
```

## Security Notes

- Never commit credentials to version control
- Use environment variables or command line arguments for sensitive data
- The scripts automatically logout from registries after pushing
- For GitHub workflows, use `secrets.GITHUB_TOKEN` which is automatically provided

## Troubleshooting

### Common Issues

1. **Authentication Failed**
   - Verify your credentials are correct
   - For Quay.io, ensure you're using a robot token for automation
   - For GHCR, ensure your GitHub token has `write:packages` permission

2. **Image Not Found**
   - Check that the Dockerfile exists in the specified path
   - Verify the working directory is correct

3. **Repository Owner Not Found**
   - For GHCR, ensure you're in a git repository with a GitHub remote
   - Or explicitly set `GITHUB_REPOSITORY_OWNER`

4. **Permission Denied**
   - Ensure the script files are executable: `chmod +x scripts/*.sh`
   - Verify you have push permissions to the target registry

5. **Deployment Preparation Failed**
   - Verify repository URLs are accessible and correct
   - Ensure you have read access to frontend and backend repositories
   - Check that git is installed and configured
   - For version file issues, ensure the deployment repo is writable

6. **Version File Corruption**
   - If `version.txt` contains invalid data, the script will attempt to normalize it
   - For completely corrupted files, delete `version.txt` and run the script again
   - The script will create a new version file starting at `1.0.0`

7. **Git Push Failed**
   - Ensure `GITHUB_TOKEN` has appropriate permissions for the deployment repository
   - Verify you're not trying to push to a protected branch without proper permissions
   - Check that the deployment repository exists and is accessible

8. **Repository Cloning Failed**
   - Verify the `FRONTEND_REPO_URL` and `BACKEND_REPO_URL` are correct
   - Ensure you have read access to both repositories
   - For private repositories, ensure your GitHub token has access

### Getting Help

Run any script with the `-h` or `--help` flag to see detailed usage information:

```bash
./scripts/prepare-deployment.sh --help
./scripts/push-to-quay.sh --help
./scripts/push-to-ghcr.sh --help
```

### Deployment Preparation Script Output

The `prepare-deployment.sh` script provides detailed output including:
- Current and new version information
- Repository cloning progress
- Project preparation status
- Changelog updates
- Git commit and push status
- Generated release notes

In test mode (`--test` flag), the script shows what would happen without making any changes.

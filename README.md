# Deployment Template

A cookiecutter template for creating deployment repositories with automated Docker image building and pushing to container registries (GHCR, Quay.io). Includes support for automatic certificate installation into Docker images.

## Features

- **Multi-registry support**: Push to GitHub Container Registry (GHCR) or Quay.io
- **Automated versioning**: Semantic version bumping with changelog generation
- **Certificate installation**: Automatically install custom certificates into Docker images
- **Flexible configuration**: Support for multiple repositories and deployment configurations
- **CI/CD ready**: Works with GitHub Actions workflows
- **Project type detection**: Supports Node.js, Python, Go, Java, .NET, and Docker projects

## Quick Start

1. **Install cookiecutter** (if not already installed):
```bash
pip install cookiecutter
```

2. **Create a new deployment repository**:
```bash
cookiecutter https://github.com/your-org/deployment-template.git
```

3. **Configure your deployment**:
   - Repository URLs for your projects
   - Docker registry preference (GHCR or Quay.io)
   - Certificate requirements for each image
   - Target certificate installation path

## Certificate Installation

One of the key features of this template is automatic certificate installation into Docker images. This is useful when your applications need to trust custom Certificate Authorities or internal certificates.

### How It Works

When an image is flagged as needing certificates:
1. The Docker image is built normally using your project's Dockerfile
2. All certificate files from the `assets/` directory are copied into the image
3. The certificate store is updated using the appropriate system commands
4. The modified image is pushed to the registry

### Configuration

Certificate installation is configured during template creation:

```json
{
    "project_slug": "my-deployment",
    "repo_urls": "https://github.com/my-org/frontend.git,https://github.com/my-org/backend.git",
    "image_names": "frontend,backend",
    "images_need_certs": "false,true",
    "cert_install_path": "/usr/local/share/ca-certificates",
    "docker_registry": "ghcr"
}
```

This creates a `deploy.config` file like:

```
docker_registry=ghcr
cert_install_path=/usr/local/share/ca-certificates

frontend=https://github.com/my-org/frontend.git
frontend_needs_certs=false
backend=https://github.com/my-org/backend.git
backend_needs_certs=true
```

### Certificate Files

Place your certificate files in the `assets/` directory:

```
assets/
├── company-root-ca.crt
├── intermediate-ca.pem
└── custom-cert.cer
```

Supported formats: `.crt`, `.pem`, `.cer`

## Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_slug` | Name of the deployment project | `my-app-deployment` |
| `repo_urls` | Comma-separated repository URLs | `https://github.com/org/frontend.git,https://github.com/org/backend.git` |
| `image_names` | Comma-separated image names | `frontend,backend` |
| `images_need_certs` | Comma-separated boolean values for certificate requirements | `false,true` |
| `cert_install_path` | Path where certificates are installed in images | `/usr/local/share/ca-certificates` |
| `start_version` | Initial version number | `0.0.1` |
| `docker_registry` | Target registry (ghcr or quay.io) | `ghcr` |

## Generated Scripts

After creating a project from this template, you'll have these scripts:

- `prepare-deployment.sh` - Manages versioning, clones repositories, and prepares for deployment
- `push-to-ghcr.sh` - Builds and pushes images to GitHub Container Registry
- `push-to-quay.sh` - Builds and pushes images to Quay.io
- `deploy-all.sh` - Deploys all configured images to the appropriate registry
- `script-utils.sh` - Common utilities used by all scripts

## Example Usage

### Deployment Preparation
```bash
# Prepare deployment with patch version bump
./scripts/prepare-deployment.sh patch

# Prepare deployment with minor version bump
./scripts/prepare-deployment.sh minor

# Test mode (no commits)
./scripts/prepare-deployment.sh patch --test
```

### Individual Image Deployment
```bash
# Push to GHCR
./scripts/push-to-ghcr.sh -i frontend

# Push to Quay.io
./scripts/push-to-quay.sh -i backend
```

### Complete Deployment
```bash
# Deploy all configured images
./scripts/deploy-all.sh
```

## Supported Base Images

Certificate installation works with:
- **Debian/Ubuntu**: Uses `apt-get` and `update-ca-certificates`
- **Alpine Linux**: Uses `apk` and `update-ca-certificates`
- **RHEL/CentOS**: Uses `yum` and `update-ca-trust`

## GitHub Actions Integration

The scripts are designed to work with GitHub Actions. Example workflow:

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
        options: [patch, minor, major]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Prepare Deployment
        run: ./scripts/prepare-deployment.sh ${{ github.event.inputs.version_bump }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Deploy All Images
        run: ./scripts/deploy-all.sh
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          QUAY_USER: ${{ secrets.QUAY_USER }}
          QUAY_PASSWORD: ${{ secrets.QUAY_PASSWORD }}
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the provided test scripts
5. Submit a pull request

## License

This template is released under the MIT License.

# Multi-Repository Deployment Template

A comprehensive Cookiecutter template for automated deployment workflows that handles multi-repository projects, version management, Docker builds, and registry deployment. Designed for GitHub CI with support for multiple container registries.

## Features

- ✅ **Cookiecutter Template**: Generate customized deployment setups for any project
- ✅ **Multi-Repository Support**: Configure unlimited repositories dynamically via `deploy.config`
- ✅ **Multi-Registry Support**: Push to GitHub Container Registry (GHCR) or Quay.io
- ✅ **Flexible Configuration**: Environment variables + config file support
- ✅ **Semantic Version Management**: Automated patch, minor, major version bumps
- ✅ **GitHub Actions Integration**: Complete CI/CD workflows included
- ✅ **Docker-First Approach**: All builds happen in containers
- ✅ **Comprehensive Logging**: Colored output with debug modes
- ✅ **Test Mode**: Validate deployments without commits
- ✅ **Backward Compatibility**: Works with existing frontend/backend setups

## Quick Start

### Generate a New Project

Create a new project using this template with [Cookiecutter](https://www.cookiecutter.io/):

```bash
# Using cookiecutter
cookiecutter https://github.com/DCC-BS/deployment-template

# Using uv (recommended)
uvx cookiecutter https://github.com/DCC-BS/deployment-template
```

You'll be prompted to configure:
- **project_slug**: Your project name/directory
- **repo_urls**: Comma-separated list of repository URLs
- **image_names**: Comma-separated list of Docker image names
- **start_version**: Initial version (default: 0.0.1)
- **docker_registry**: Choose between "ghcr" or "quay.io"

### Example Configuration

```
project_slug: my-microservices
repo_urls: https://github.com/myorg/frontend.git,https://github.com/myorg/api.git,https://github.com/myorg/worker.git
image_names: frontend,api,worker
start_version: 1.0.0
docker_registry: ghcr
```

This generates a complete deployment setup in the `my-microservices/` directory.

## Project Structure

After generating your project, you'll get:

```
my-project/
├── .github/
│   ├── workflows/
│   │   ├── deploy.yml           # Main deployment workflow
│   │   └── test-build.yml       # Test builds without deployment
│   └── actions/
│       └── build-and-test/      # Reusable composite action
├── scripts/
│   ├── prepare-deployment.sh    # Main preparation script
│   ├── deploy-all.sh           # Deploy to configured registry
│   ├── push-to-ghcr.sh         # GitHub Container Registry push
│   ├── push-to-quay.sh         # Quay.io registry push
│   ├── script-utils.sh         # Shared utility functions
│   └── README.md               # Detailed script documentation
├── deploy.config               # Repository and registry configuration
├── version.txt                 # Current version (auto-managed)
└── README.md                   # Project-specific documentation
```

## Configuration

### Repository Configuration (`deploy.config`)

The heart of the system is the `deploy.config` file, which defines your repositories and registry settings:

```bash
# Docker registry configuration
docker_registry=ghcr

# Repository mappings (image_name=repository_url)
frontend=https://github.com/myorg/frontend-app.git
api=https://github.com/myorg/api-service.git
worker=https://github.com/myorg/background-worker.git
mobile=https://github.com/myorg/mobile-app.git
```

### Registry-Specific Configuration

#### GitHub Container Registry (GHCR)
```bash
# Automatically provided in GitHub Actions
GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
GITHUB_REPOSITORY_OWNER="your-org"
GITHUB_ACTOR="your-username"
```

#### Quay.io Registry
```bash
# set in .github/workflows/deploy.yml or test-build.yml
# dont forget to set the organization and team in both workflows
QUAY_USER="your-username"
QUAY_PASSWORD="your-password-or-token"
QUAY_ORGANIZATION="your-org"        # Optional
QUAY_TEAM="your-team"              # Optional
```


## Usage

### GitHub Actions Workflows

The template includes two pre-configured workflows:

#### 1. **Deploy Workflow** (`deploy.yml`)
- **Trigger**: Manual dispatch with version bump selection
- **Actions**: Prepares deployment, builds images, pushes to registry
- **Permissions**: Handles version commits and registry pushes
- **Registry**: Deploys to configured registry (GHCR or Quay)

```bash
# Triggered via GitHub UI or API
# Choose: patch, minor, or major version bump
```

#### 2. **Test Build Workflow** (`test-build.yml`)
- **Trigger**: Pull requests, pushes to develop, manual dispatch
- **Actions**: Tests deployment process without committing or pushing
- **Purpose**: Validate changes before actual deployment

### Local Usage

#### Prepare Deployment
```bash
# Navigate to your generated project
cd my-project

# Standard deployment with version bump
./scripts/prepare-deployment.sh patch

# Test mode (no commits/pushes)
./scripts/prepare-deployment.sh minor --test

# Deploy all configured images
./scripts/deploy-all.sh

# Deploy specific registry
./scripts/push-to-ghcr.sh frontend
./scripts/push-to-quay.sh api
```

#### Version Management
```bash
# Current version is automatically managed in version.txt
cat version.txt

# Version bumps:
./scripts/prepare-deployment.sh patch  # 1.0.0 → 1.0.1
./scripts/prepare-deployment.sh minor  # 1.0.1 → 1.1.0  
./scripts/prepare-deployment.sh major  # 1.1.0 → 2.0.0
```

### Script Features

#### Repository Management
- **Dynamic Configuration**: Add/remove repositories via `deploy.config`
- **Automatic Cloning**: Fresh clones ensure clean builds
- **Multi-Repository Support**: Handle any number of repositories
- **Validation**: Verifies repository access and Docker configurations

#### Version Control
- **Semantic Versioning**: Follows SemVer specification
- **Git Integration**: Automatic commits and pushes
- **Tag Management**: Creates version tags and releases
- **Rollback Support**: Version history preserved

## Advanced Configuration

### Multi-Registry Deployment

Deploy the same images to multiple registries:

```bash
# Configure multiple registries in deploy.config
docker_registry=ghcr,quay

# Or use environment variable
export DOCKER_REGISTRY="ghcr,quay"

# Deploy to all configured registries
./scripts/deploy-all.sh
```

### Custom Docker Builds

All builds happen within Docker containers. Customize builds by editing Dockerfiles in your repositories:

#### Example Frontend Dockerfile
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

#### Example API Dockerfile
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN python -m pytest
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Custom Tags and Metadata

```bash
# Add custom tags
export ADDITIONAL_TAG="hotfix-2024-06"

# Custom Dockerfile path
export DOCKERFILE_PATH="docker/production.Dockerfile"

# Add build metadata
export BUILD_METADATA="branch=main,commit=$(git rev-parse HEAD)"
```

### Environment-Specific Deployments

```bash
# Development environment
export DOCKER_REGISTRY="ghcr.io"
export IMAGE_TAG_SUFFIX="-dev"

# Production environment  
export DOCKER_REGISTRY="quay.io"
export IMAGE_TAG_SUFFIX=""

# Staging with specific version
export FORCE_VERSION="1.2.3-staging"
```

## Extending the Template

### Adding New Scripts

Create custom deployment scripts in the `scripts/` directory:

```bash
# Example: scripts/deploy-staging.sh
#!/bin/bash
source "$(dirname "$0")/script-utils.sh"

log_info "Deploying to staging environment..."
# Your custom deployment logic here
```

### Custom GitHub Actions

Extend the workflows by adding new jobs or steps:

```yaml
# .github/workflows/custom-deploy.yml
name: Custom Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, staging, prod]

jobs:
  custom-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Custom Deploy
        run: ./scripts/custom-deploy.sh ${{ inputs.environment }}
```

## Troubleshooting

### Common Issues

#### 1. **Repository Access Issues**
```bash
# Check repository URLs and access
./scripts/prepare-deployment.sh patch --test

# Verify SSH keys or token permissions
git clone <repository-url> temp-test
rm -rf temp-test
```

#### 2. **Docker Registry Authentication**
```bash
# For GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin

# For Quay.io  
echo $QUAY_PASSWORD | docker login quay.io -u $QUAY_USER --password-stdin
```

#### 3. **Version Management Issues**
```bash
# Reset version file
echo "1.0.0" > version.txt
git add version.txt
git commit -m "Reset version"

# Check git configuration
git config user.name
git config user.email
```

#### 4. **Script Permission Issues**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Fix line endings (if editing on Windows)
dos2unix scripts/*.sh
```

#### 5. **Configuration Problems**
```bash
# Validate deploy.config
cat deploy.config

# Check environment variables
env | grep -E "(REPO_URL|DOCKER_REGISTRY|GITHUB_TOKEN|QUAY_)"

# Test configuration loading
./scripts/prepare-deployment.sh patch --test
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Enable debug mode
export SCRIPT_UTILS_DEBUG=true

# Run with debug output
./scripts/prepare-deployment.sh patch --test

# Or add to script directly
set -x  # Enable bash debug mode
```

### Registry-Specific Issues

#### GitHub Container Registry (GHCR)
- Ensure `GITHUB_TOKEN` has `write:packages` scope
- Verify repository visibility settings
- Check organization package permissions

#### Quay.io Registry
- Verify robot account permissions
- Check repository visibility in Quay UI
- Ensure organization/team access rights

### GitHub Actions Troubleshooting

```yaml
# Add debug step to workflow
- name: Debug Environment
  run: |
    echo "Repository: $GITHUB_REPOSITORY"
    echo "Actor: $GITHUB_ACTOR"
    echo "Working Directory: $(pwd)"
    ls -la
    env | sort
```

## Examples

### Simple Web Application
```bash
# Generate project
uvx cookiecutter https://github.com/DCC-BS/deployment-template

# Configuration
project_slug: my-webapp
repo_urls: https://github.com/myorg/frontend.git,https://github.com/myorg/api.git
image_names: webapp,api
docker_registry: ghcr
```

### Microservices Architecture
```bash
# Configuration for multiple services
project_slug: microservices-platform
repo_urls: https://github.com/myorg/gateway.git,https://github.com/myorg/auth-service.git,https://github.com/myorg/user-service.git,https://github.com/myorg/payment-service.git
image_names: gateway,auth,users,payments
docker_registry: quay.io
```

### Mobile + Backend
```bash
# Configuration for mobile app with backend
project_slug: mobile-app
repo_urls: https://github.com/myorg/mobile-app.git,https://github.com/myorg/backend-api.git,https://github.com/myorg/admin-panel.git
image_names: mobile,api,admin
docker_registry: ghcr
```

## Migration Guide

### From Single Repository Setup
If you're migrating from a single repository deployment:

1. **Create new configuration**:
   ```bash
   # Old way (single repo)
   export FRONTEND_REPO_URL="https://github.com/myorg/app.git"
   
   # New way (deploy.config)
   echo "frontend=https://github.com/myorg/app.git" > deploy.config
   ```

2. **Update workflows**: Replace old workflow files with generated ones

3. **Test migration**: Run in test mode first
   ```bash
   ./scripts/prepare-deployment.sh patch --test
   ```

### From Manual Docker Builds
If you're migrating from manual Docker builds:

1. **Move Dockerfiles**: Ensure each repository has a `Dockerfile`
2. **Update CI/CD**: Replace manual steps with generated workflows  
3. **Configure registries**: Set up GHCR or Quay.io authentication

## Best Practices

### Repository Structure
- Each repository should have a `Dockerfile` in the root
- Use multi-stage builds for optimization
- Include health checks in Docker images
- Tag images with semantic versions

### Security
- Use robot accounts for Quay.io (not personal accounts)
- Rotate registry tokens regularly
- Limit token permissions to minimum required
- Use secrets management in GitHub Actions

### Version Management
- Use conventional commits for clear version history
- Tag releases consistently
- Keep CHANGELOG.md updated
- Use protected branches for version control

### Testing
- Always test deployments in staging first
- Use test workflows for pull request validation
- Implement smoke tests for deployed services
- Monitor deployment success metrics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with a sample project
5. Submit a pull request

### Development Setup
```bash
# Clone the template
git clone https://github.com/DCC-BS/deployment-template.git

# Test locally
cd deployment-template
uvx cookiecutter .

# Make changes and test again
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- **Documentation**: Check `scripts/README.md` for detailed script documentation
- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Examples**: See the `examples/` directory for sample configurations

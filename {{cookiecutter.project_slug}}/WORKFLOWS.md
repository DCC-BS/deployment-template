# CI/CD Workflows Documentation

This repository contains two main GitHub Actions workflows for building and deploying applications:

## Workflows

### 1. Deploy Workflow (`deploy.yml`)
**Purpose**: Production deployment workflow that builds, tests, and deploys applications.

**Triggers**:
- Manual trigger (`workflow_dispatch`) with version bump selection

**Features**:
- ✅ Commits version changes to git
- ✅ Pushes Docker images to registries
- ✅ Creates GitHub releases
- ✅ Updates changelog
- ✅ Full deployment process

**Usage**:
```bash
# Trigger manually from GitHub Actions tab
# Select version bump type: patch, minor, or major
```

### 2. Test Build Workflow (`test-build.yml`)
**Purpose**: Test and validation workflow that runs all build processes without making any permanent changes.

**Triggers**:
- Manual trigger (`workflow_dispatch`) with version bump selection (for testing)
- Pull requests to `main` or `develop` branches
- Pushes to `develop` branch

**Features**:
- ❌ Does NOT commit any changes
- ❌ Does NOT push Docker images to registries
- ❌ Does NOT create releases
- ✅ Validates build process
- ✅ Tests Docker builds locally
- ✅ Runs vulnerability scans
- ✅ Generates test reports
- ✅ Uploads test artifacts

## Reusable Action

### Build and Test Action (`.github/actions/build-and-test/`)
A reusable composite action that handles common build and test operations:

**Inputs**:
- `version-bump`: Version bump type (patch, minor, major)
- `commit-changes`: Whether to commit changes (true/false)
- `github-token`: GitHub authentication token

**Outputs**:
- `version`: Generated version number
- `frontend-changed`: Whether frontend code was detected
- `backend-changed`: Whether backend code was detected

**Features**:
- Sets up Bun, UV, Node.js, and Python environments
- Configures dependency caching
- Runs deployment preparation script
- Handles version management
- Provides build readiness checks

## Repository Structure

```
.github/
├── workflows/
│   ├── deploy.yml          # Production deployment workflow
│   └── test-build.yml      # Test/validation workflow
└── actions/
    ├── build-and-test/     # Reusable build action
    │   └── action.yml
    └── dockerfile-build/   # Docker build action
        └── action.yml
```

## Configuration

### Environment Variables
The workflows expect the following repository secrets:

**Required**:
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

**Optional** (for multi-registry support):
- `LINKYARD_CONTAINER_REGISTRY_USER`
- `LINKYARD_CONTAINER_REGISTRY_PASSWORD`
- `QUAY_CONTAINER_REGISTRY_USER`
- `QUAY_CONTAINER_REGISTRY_PASSWORD`

### Project Structure
The workflows expect your repository to have:

```
frontend/           # Frontend application code
├── package.json    # Bun/Node.js dependencies
├── bun.lockb       # Bun lock file
└── Dockerfile      # Frontend Docker build

backend/            # Backend application code
├── pyproject.toml  # Python dependencies (UV)
├── uv.lock         # UV lock file
└── Dockerfile      # Backend Docker build

scripts/
└── prepare-deployment.sh  # Deployment preparation script
```

## Usage Examples

### Running Tests Before Deployment
1. Create a pull request to `main` or `develop`
2. The test build workflow will automatically run
3. Review the test results and artifacts
4. Merge when tests pass

### Deploying to Production
1. Go to GitHub Actions tab
2. Select "Prepare and Deploy Application" workflow
3. Click "Run workflow"
4. Choose version bump type (patch/minor/major)
5. Monitor the deployment progress

### Testing Version Bumps
1. Go to GitHub Actions tab
2. Select "Test Build Without Deploy" workflow
3. Click "Run workflow"
4. Choose version bump type to test
5. Review the generated version and build process

## Customization

### Adding New Build Steps
Edit the `.github/actions/build-and-test/action.yml` file to add new steps that should be common to both workflows.

### Modifying Docker Builds
The workflows use the existing `dockerfile-build` action. Modify that action to change Docker build behavior.

### Changing Triggers
Edit the `on:` sections in the workflow files to change when workflows are triggered.

## Troubleshooting

### Common Issues

1. **Missing Dockerfiles**: Ensure both `frontend/Dockerfile` and `backend/Dockerfile` exist
2. **Dependency Files**: Check that `frontend/package.json` and `backend/pyproject.toml` exist
3. **Permissions**: Ensure the repository has proper permissions for the actions
4. **Secrets**: Verify required secrets are configured in repository settings

### Debug Mode
Add the following to any workflow step for debug output:
```yaml
- name: Debug
  run: |
    echo "Debug information..."
    env
```

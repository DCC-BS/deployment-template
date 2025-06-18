# Deployment Preparation Script

This repository contains a comprehensive deployment preparation script designed for GitHub CI that handles cloning repositories, caching dependencies, version management, and preparing projects for Docker builds.

## Features

- ✅ Clone frontend and backend repositories into separate folders
- ✅ Cache Bun packages for faster frontend builds
- ✅ Cache UV Python modules for faster backend builds
- ✅ Customizable GitHub repository URLs via environment variables
- ✅ Semantic version management (patch, minor, major)
- ✅ Automatic version file creation and updates
- ✅ Git commit and push of version updates
- ✅ Colored logging output for better visibility
- ✅ Project preparation for Docker builds

## Usage

### Local Usage

```bash
# Run with default patch version bump
./scripts/prepare-deployment.sh

# Specify version bump type
./scripts/prepare-deployment.sh patch   # 1.0.0 -> 1.0.1
./scripts/prepare-deployment.sh minor   # 1.0.0 -> 1.1.0
./scripts/prepare-deployment.sh major   # 1.0.0 -> 2.0.0
```

### Environment Variables

Set these environment variables to customize repository URLs:

```bash
export FRONTEND_REPO_URL="https://github.com/your-org/your-frontend-repo.git"
export BACKEND_REPO_URL="https://github.com/your-org/your-backend-repo.git"
export GITHUB_TOKEN="your-github-token"  # Required for pushing changes
```

### GitHub Actions Usage

The included workflow file (`.github/workflows/deploy.yml`) demonstrates how to use this script in GitHub CI:

1. **Manual Trigger**: Use `workflow_dispatch` to manually trigger deployment preparation
2. **Input Parameters**: Choose version bump type and repository URLs
3. **Caching**: Automatic caching for both Bun and UV dependencies
4. **Docker Build Step**: Placeholder for your Docker build commands
5. **Release Creation**: Automatically creates GitHub releases

#### Required Secrets

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions (no setup required)

#### Optional Repository Secrets

If your repositories are private, you may need to set up additional authentication:

- `FRONTEND_REPO_TOKEN`: Personal access token for frontend repository
- `BACKEND_REPO_TOKEN`: Personal access token for backend repository

## Script Components

### 1. Repository Cloning
- Clones frontend repository to `./frontend`
- Clones backend repository to `./backend`
- Removes existing directories before cloning

### 2. Dependency Caching

#### Frontend (Bun)
- Detects `bun.lockb` files
- Creates cache keys based on lockfile hash
- Configures Bun cache directory

#### Backend (UV)
- Detects `uv.lock` or `pyproject.toml` files
- Creates cache keys based on dependency file hash
- Configures UV cache directory

### 3. Version Management
- Creates `version.txt` file if it doesn't exist (starts at 1.0.0)
- Supports semantic versioning with patch, minor, and major bumps
- Automatically commits and pushes version updates

### 4. Project Preparation
- Verifies project structure and required files
- Checks for Dockerfiles in both frontend and backend
- Prepares projects for Docker build process
- No actual building (handled by Docker)

## File Structure

```
text-mate-deploy/
├── scripts/
│   └── prepare-deployment.sh   # Main deployment preparation script
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Actions workflow
├── version.txt                 # Version file (created automatically)
└── README.md                  # This file
```

## Prerequisites

### Local Development
- Git
- Bash shell
- Bun (for frontend builds)
- UV (for backend builds)

### GitHub Actions
All prerequisites are automatically installed via the workflow:
- Bun via `oven-sh/setup-bun`
- UV via `astral-sh/setup-uv`
- Node.js and Python as fallbacks

## Customization

### Adding Custom Build Steps

Edit the `build_projects()` function in `deploy.sh` to add custom build commands:

```bash
# Build frontend
if [ -d "./frontend" ]; then
    cd ./frontend
    # Add your custom frontend build commands here
    bun run build
    bun run test
    cd ..
fi

# Build backend
if [ -d "./backend" ]; then
    cd ./backend
    # Add your custom backend build commands here
    uv run pytest
    uv build
    cd ..
fi
```

### Modifying Cache Strategies

The caching setup can be customized in the `setup_frontend_cache()` and `setup_backend_cache()` functions.

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure the script is executable
   ```bash
   chmod +x scripts/prepare-deployment.sh
   ```

2. **Git Push Fails**: Ensure `GITHUB_TOKEN` is set and has write permissions
   ```bash
   export GITHUB_TOKEN="your_token_here"
   ```

3. **Repository Not Found**: Verify the repository URLs and access permissions
   ```bash
   export FRONTEND_REPO_URL="https://github.com/correct-org/frontend-repo.git"
   ```

### Debug Mode

For verbose output, you can add debug flags to the script:

```bash
# Add at the top of prepare-deployment.sh
set -x  # Enable debug mode
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the script locally
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Changelog

### Version 1.0.5 - 2025-06-18 14:44:52

- **Version**: 1.0.5
- **Type**: patch version bump
- **Git Commit**: [dae664643552c995a42b00e21012e809ad47b724](/commit/dae664643552c995a42b00e21012e809ad47b724)
- **Commit Message**: chore: bump version to 1.0.5

---


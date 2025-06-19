# Deployment Preparation Script

This repository contains a comprehensive deployment preparation script designed for GitHub CI that handles cloning repositories, version management, and preparing projects for Docker builds.

## Features

- ✅ Clone frontend and backend repositories into separate folders
- ✅ Customizable GitHub repository URLs via environment variables
- ✅ Semantic version management (patch, minor, major)
- ✅ Automatic version file creation and updates
- ✅ Git commit and push of version updates
- ✅ Colored logging output for better visibility
- ✅ Project preparation for Docker builds
- ✅ Docker-first approach (no dependency caching or building)

## Usage

### Cookiecutter
Create a new project using this template with [Cookiecutter](https://www.cookiecutter.io/):

```bash
cookiecutter https://github.com/DCC-BS/deployment-template

# or with uv
uvx cookiecutter https://github.com/DCC-BS/deployment-template
```

### GitHub Actions Usage

The included workflow file (`.github/workflows/deploy.yml`) to run this script in GitHub CI:

1. **Manual Trigger**: Use `workflow_dispatch` to manually trigger deployment preparation
2. **Input Parameters**: Choose version bump type and repository URLs
3. **Docker Build Step**: Builds Docker images without dependency caching
4. **Release Creation**: Automatically creates GitHub releases

#### Required Secrets

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions (no setup required)

## Script Components

### 1. Repository Cloning
- Clones frontend repository to `./frontend`
- Clones backend repository to `./backend`
- Removes existing directories before cloning

#### Frontend Dependencies
- Managed within `frontend/Dockerfile`
- Built during Docker image creation
- No external caching required

#### Backend Dependencies  
- Managed within `backend/Dockerfile`
- Built during Docker image creation
- No external caching required

### 3. Version Management
- Creates `version.txt` file if it doesn't exist (starts at 1.0.0)
- Supports semantic versioning with patch, minor, and major bumps
- Automatically commits and pushes version updates

### 4. Project Preparation
- Verifies project structure and required files
- Checks for Dockerfiles in both frontend and backend
- Prepares projects for Docker build process
- All building happens within Docker containers


## Customization

### Adding Custom Build Steps

All builds are handled within Docker containers using the respective Dockerfiles. To customize builds:

**Frontend builds**: Edit `frontend/Dockerfile` in your frontend repository
```dockerfile
# Example frontend Dockerfile customization
FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
```

**Backend builds**: Edit `backend/Dockerfile` in your backend repository  
```dockerfile
# Example backend Dockerfile customization
FROM python:3.11
WORKDIR /app
COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY . .
RUN python -m pytest
```

### Docker-First Approach

This template uses a Docker-first approach where all dependency management and building happens within containers, eliminating the need for external caching or environment setup.

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

4. **Docker Build Fails**: Ensure Dockerfiles exist in both frontend and backend repositories
   - Check `frontend/Dockerfile` exists and is valid
   - Check `backend/Dockerfile` exists and is valid

### Debug Mode

For verbose output, you can add debug flags to the script:

```bash
# Add at the top of prepare-deployment.sh
set -x  # Enable debug mode
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

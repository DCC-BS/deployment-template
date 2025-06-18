#!/bin/bash

# Deployment preparation script for GitHub CI
# Usage: ./prepare-deployment.sh [patch|minor|major]

set -e  # Exit on any error

# Configuration - Customize these URLs for your repos
FRONTEND_REPO_URL="${FRONTEND_REPO_URL:-https://github.com/your-org/frontend-repo.git}"
BACKEND_REPO_URL="${BACKEND_REPO_URL:-https://github.com/your-org/backend-repo.git}"

# Version bump type (default to patch if not specified)
VERSION_BUMP="${1:-patch}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate version bump parameter
validate_version_bump() {
    if [[ ! "$VERSION_BUMP" =~ ^(patch|minor|major)$ ]]; then
        log_error "Invalid version bump type: $VERSION_BUMP"
        log_error "Usage: $0 [patch|minor|major]"
        exit 1
    fi
    log_info "Version bump type: $VERSION_BUMP"
}

# Create and read version file
manage_version() {
    VERSION_FILE="version.txt"
    
    if [ ! -f "$VERSION_FILE" ]; then
        log_info "Creating initial version file"
        echo "1.0.0" > "$VERSION_FILE"
        CURRENT_VERSION="1.0.0"
    else
        CURRENT_VERSION=$(cat "$VERSION_FILE")
    fi
    
    log_info "Current version: $CURRENT_VERSION"
    
    # Parse version components
    IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
    
    # Bump version based on parameter
    case "$VERSION_BUMP" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
    esac
    
    NEW_VERSION="$major.$minor.$patch"
    echo "$NEW_VERSION" > "$VERSION_FILE"
    log_success "Version updated to: $NEW_VERSION"
}

# Clone repositories
clone_repositories() {
    log_info "Cloning repositories..."
    
    # Remove existing directories if they exist
    [ -d "./frontend" ] && rm -rf "./frontend"
    [ -d "./backend" ] && rm -rf "./backend"
    
    # Clone frontend repository
    log_info "Cloning frontend repository from: $FRONTEND_REPO_URL"
    git clone "$FRONTEND_REPO_URL" ./frontend
    log_success "Frontend repository cloned successfully"
    
    # Clone backend repository
    log_info "Cloning backend repository from: $BACKEND_REPO_URL"
    git clone "$BACKEND_REPO_URL" ./backend
    log_success "Backend repository cloned successfully"
}

# Setup frontend caching for Bun
setup_frontend_cache() {
    log_info "Setting up frontend caching for Bun..."
    
    cd ./frontend
    
    # Check if bun.lockb exists
    if [ -f "bun.lockb" ]; then
        log_info "Found bun.lockb, setting up cache..."
        
        # Create cache key based on lockfile hash
        CACHE_KEY="bun-$(sha256sum bun.lockb | cut -d' ' -f1)"
        log_info "Cache key: $CACHE_KEY"
        
        # In GitHub Actions, you would use this cache key
        # For local development, we'll create a cache directory
        mkdir -p ~/.bun-cache
        
        # Set Bun cache directory
        export BUN_CACHE_DIR=~/.bun-cache
        
        log_success "Bun cache configured"
    else
        log_warning "No bun.lockb found, skipping Bun cache setup"
    fi
    
    cd ..
}

# Setup backend caching for UV
setup_backend_cache() {
    log_info "Setting up backend caching for UV..."
    
    cd ./backend
    
    # Check if uv.lock or pyproject.toml exists
    if [ -f "uv.lock" ] || [ -f "pyproject.toml" ]; then
        log_info "Found UV project files, setting up cache..."
        
        # Create cache key based on lock file or pyproject.toml hash
        if [ -f "uv.lock" ]; then
            CACHE_KEY="uv-$(sha256sum uv.lock | cut -d' ' -f1)"
        else
            CACHE_KEY="uv-$(sha256sum pyproject.toml | cut -d' ' -f1)"
        fi
        
        log_info "Cache key: $CACHE_KEY"
        
        # Set UV cache directory
        export UV_CACHE_DIR=~/.uv-cache
        mkdir -p "$UV_CACHE_DIR"
        
        log_success "UV cache configured"
    else
        log_warning "No uv.lock or pyproject.toml found, skipping UV cache setup"
    fi
    
    cd ..
}

# Install dependencies with caching
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Install frontend dependencies
    if [ -d "./frontend" ]; then
        log_info "Installing frontend dependencies with Bun..."
        cd ./frontend
        
        if command -v bun &> /dev/null; then
            bun install
            log_success "Frontend dependencies installed"
        else
            log_warning "Bun not found, skipping frontend dependency installation"
        fi
        
        cd ..
    fi
    
    # Install backend dependencies
    if [ -d "./backend" ]; then
        log_info "Installing backend dependencies with UV..."
        cd ./backend
        
        if command -v uv &> /dev/null; then
            uv sync
            log_success "Backend dependencies installed"
        else
            log_warning "UV not found, skipping backend dependency installation"
        fi
        
        cd ..
    fi
}

# Prepare projects for Docker build
prepare_projects() {
    log_info "Preparing projects for Docker build..."
    
    # Frontend preparation
    if [ -d "./frontend" ]; then
        log_info "Frontend project ready for Docker build"
        cd ./frontend
        
        # Verify project structure
        if [ -f "package.json" ]; then
            log_info "Found package.json in frontend project"
        fi
        if [ -f "Dockerfile" ]; then
            log_info "Found Dockerfile in frontend project"
        fi
        
        cd ..
    fi
    
    # Backend preparation
    if [ -d "./backend" ]; then
        log_info "Backend project ready for Docker build"
        cd ./backend
        
        # Verify project structure
        if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
            log_info "Found Python dependency files in backend project"
        fi
        if [ -f "Dockerfile" ]; then
            log_info "Found Dockerfile in backend project"
        fi
        
        cd ..
    fi
    
    log_success "Projects prepared for Docker build"
}

# Commit and push version update
commit_version_update() {
    log_info "Committing and pushing version update..."
    
    # Add version file to git
    git add version.txt
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        log_warning "No version changes to commit"
        return
    fi
    
    # Commit the version update
    git commit -m "chore: bump version to $NEW_VERSION"
    
    # Push to remote (assumes origin remote exists and user has push permissions)
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        log_info "Pushing version update to remote repository..."
        git push origin HEAD
        log_success "Version update pushed successfully"
    else
        log_warning "GITHUB_TOKEN not set, skipping push to remote"
        log_info "To push manually, run: git push origin HEAD"
    fi
}

# Main execution
main() {
    log_info "Starting deployment preparation process..."
    log_info "Frontend repo: $FRONTEND_REPO_URL"
    log_info "Backend repo: $BACKEND_REPO_URL"
    
    validate_version_bump
    manage_version
    clone_repositories
    setup_frontend_cache
    setup_backend_cache
    install_dependencies
    prepare_projects
    commit_version_update
    
    log_success "Deployment preparation completed successfully!"
    log_info "New version: $NEW_VERSION"
    log_info "Projects are ready for Docker build"
}

# Run main function
main "$@"
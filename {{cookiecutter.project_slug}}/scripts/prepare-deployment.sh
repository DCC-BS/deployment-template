#!/bin/bash

# Deployment preparation script for GitHub CI
# Usage: ./prepare-deployment.sh [patch|minor|major] [--test|--no-commit]
# 
# Arguments:
#   - First argument: Version bump type (patch, minor, major)
#   - Second argument (optional): Mode flag
#     --test or --no-commit: Run in test mode (no commits, no pushes)

set -e  # Exit on any error

# Source .env file if it exists
if [ -f ".env" ]; then
    source .env
fi

# Configuration - Customize these URLs for your repos
FRONTEND_REPO_URL="${FRONTEND_REPO_URL:-https://github.com/your-org/frontend-repo.git}"
BACKEND_REPO_URL="${BACKEND_REPO_URL:-https://github.com/your-org/backend-repo.git}"

# Parse arguments
VERSION_BUMP="${1:-patch}"
MODE_FLAG="${2:-}"

# Determine if this is a test run
TEST_MODE=false
if [[ "$MODE_FLAG" == "--test" || "$MODE_FLAG" == "--no-commit" ]]; then
    TEST_MODE=true
fi

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

log_test() {
    if [ "$TEST_MODE" == "true" ]; then
        echo -e "${YELLOW}[TEST MODE]${NC} $1"
    fi
}

# Validate version bump parameter
validate_version_bump() {
    if [[ ! "$VERSION_BUMP" =~ ^(patch|minor|major)$ ]]; then
        log_error "Invalid version bump type: $VERSION_BUMP"
        log_error "Usage: $0 [patch|minor|major] [--test|--no-commit]"
        exit 1
    fi
    
    if [ "$TEST_MODE" == "true" ]; then
        log_test "Running in TEST MODE - no commits or pushes will be made"
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
    
    # Bump version on parameter
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

# Create or update changelog in README
update_changelog() {
    if [ "$TEST_MODE" == "true" ]; then
        log_test "Skipping changelog update (test mode)"
        log_test "Would update README.md with version $NEW_VERSION"
        return
    fi
    
    log_info "Updating changelog in README..."
    
    README_FILE="README.md"
    CHANGELOG_SECTION="## Changelog"
    
    # Get current date
    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get frontend commit information
    FRONTEND_COMMIT_HASH=""
    FRONTEND_COMMIT_MESSAGE=""
    FRONTEND_WEB_URL=""
    
    if [ -d "./frontend" ]; then
        cd ./frontend
        FRONTEND_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        FRONTEND_COMMIT_MESSAGE=$(git log -1 --pretty=format:'%s' 2>/dev/null || echo "No commit message")
        
        # Get frontend repo web URL
        FRONTEND_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $FRONTEND_REMOTE_URL =~ git@github\.com:(.+)\.git ]]; then
            FRONTEND_REPO_PATH="${BASH_REMATCH[1]}"
            FRONTEND_WEB_URL="https://github.com/$FRONTEND_REPO_PATH"
        elif [[ $FRONTEND_REMOTE_URL =~ https://github\.com/(.+)\.git ]]; then
            FRONTEND_REPO_PATH="${BASH_REMATCH[1]}"
            FRONTEND_WEB_URL="https://github.com/$FRONTEND_REPO_PATH"
        else
            FRONTEND_WEB_URL="$FRONTEND_REMOTE_URL"
        fi
        cd ..
    fi
    
    # Get backend commit information
    BACKEND_COMMIT_HASH=""
    BACKEND_COMMIT_MESSAGE=""
    BACKEND_WEB_URL=""
    
    if [ -d "./backend" ]; then
        cd ./backend
        BACKEND_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        BACKEND_COMMIT_MESSAGE=$(git log -1 --pretty=format:'%s' 2>/dev/null || echo "No commit message")
        
        # Get backend repo web URL
        BACKEND_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $BACKEND_REMOTE_URL =~ git@github\.com:(.+)\.git ]]; then
            BACKEND_REPO_PATH="${BASH_REMATCH[1]}"
            BACKEND_WEB_URL="https://github.com/$BACKEND_REPO_PATH"
        elif [[ $BACKEND_REMOTE_URL =~ https://github\.com/(.+)\.git ]]; then
            BACKEND_REPO_PATH="${BASH_REMATCH[1]}"
            BACKEND_WEB_URL="https://github.com/$BACKEND_REPO_PATH"
        else
            BACKEND_WEB_URL="$BACKEND_REMOTE_URL"
        fi
        cd ..
    fi
    
    # Create changelog entry with frontend and backend commit info
    CHANGELOG_ENTRY="### Version $NEW_VERSION - $CURRENT_DATE

- **Version**: $NEW_VERSION
- **Type**: $VERSION_BUMP version bump

#### Frontend Repository
- **Commit**: [\`${FRONTEND_COMMIT_HASH:0:8}\`]($FRONTEND_WEB_URL/commit/$FRONTEND_COMMIT_HASH)
- **Message**: $FRONTEND_COMMIT_MESSAGE

#### Backend Repository
- **Commit**: [\`${BACKEND_COMMIT_HASH:0:8}\`]($BACKEND_WEB_URL/commit/$BACKEND_COMMIT_HASH)
- **Message**: $BACKEND_COMMIT_MESSAGE

---
"
    
    # Check if README exists
    if [ ! -f "$README_FILE" ]; then
        log_info "Creating new README.md file..."
        cat > "$README_FILE" << EOF
# Deployment Repository

This repository contains deployment configurations and scripts.

$CHANGELOG_SECTION

$CHANGELOG_ENTRY
EOF
    else
        # Check if changelog section exists
        if grep -q "^$CHANGELOG_SECTION" "$README_FILE"; then
            log_info "Updating existing changelog section..."
            # Create a temporary file with the new entry
            TEMP_FILE=$(mktemp)
            
            # Add the new entry after the changelog header
            awk -v entry="$CHANGELOG_ENTRY" '
                /^## Changelog/ { 
                    print $0; 
                    print ""; 
                    print entry; 
                    next 
                }
                { print }
            ' "$README_FILE" > "$TEMP_FILE"
            
            # Replace the original file
            mv "$TEMP_FILE" "$README_FILE"
        else
            log_info "Adding new changelog section to README..."
            # Add changelog section at the end of the file
            echo "" >> "$README_FILE"
            echo "$CHANGELOG_SECTION" >> "$README_FILE"
            echo "" >> "$README_FILE"
            echo "$CHANGELOG_ENTRY" >> "$README_FILE"
        fi
    fi
    
    log_success "Changelog updated in README.md"
}

# Output changelog for GitHub Actions release
output_changelog_for_release() {
    log_info "Outputting changelog for GitHub Actions release..."
    
    # Get current date
    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get frontend commit information
    FRONTEND_COMMIT_HASH=""
    FRONTEND_COMMIT_MESSAGE=""
    FRONTEND_WEB_URL=""
    
    if [ -d "./frontend" ]; then
        cd ./frontend
        FRONTEND_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        FRONTEND_COMMIT_MESSAGE=$(git log -1 --pretty=format:'%s' 2>/dev/null || echo "No commit message")
        
        # Get frontend repo web URL
        FRONTEND_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $FRONTEND_REMOTE_URL =~ git@github\.com:(.+)\.git ]]; then
            FRONTEND_REPO_PATH="${BASH_REMATCH[1]}"
            FRONTEND_WEB_URL="https://github.com/$FRONTEND_REPO_PATH"
        elif [[ $FRONTEND_REMOTE_URL =~ https://github\.com/(.+)\.git ]]; then
            FRONTEND_REPO_PATH="${BASH_REMATCH[1]}"
            FRONTEND_WEB_URL="https://github.com/$FRONTEND_REPO_PATH"
        else
            FRONTEND_WEB_URL="$FRONTEND_REMOTE_URL"
        fi
        cd ..
    fi
    
    # Get backend commit information
    BACKEND_COMMIT_HASH=""
    BACKEND_COMMIT_MESSAGE=""
    BACKEND_WEB_URL=""
    
    if [ -d "./backend" ]; then
        cd ./backend
        BACKEND_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        BACKEND_COMMIT_MESSAGE=$(git log -1 --pretty=format:'%s' 2>/dev/null || echo "No commit message")
        
        # Get backend repo web URL
        BACKEND_REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ $BACKEND_REMOTE_URL =~ git@github\.com:(.+)\.git ]]; then
            BACKEND_REPO_PATH="${BASH_REMATCH[1]}"
            BACKEND_WEB_URL="https://github.com/$BACKEND_REPO_PATH"
        elif [[ $BACKEND_REMOTE_URL =~ https://github\.com/(.+)\.git ]]; then
            BACKEND_REPO_PATH="${BASH_REMATCH[1]}"
            BACKEND_WEB_URL="https://github.com/$BACKEND_REPO_PATH"
        else
            BACKEND_WEB_URL="$BACKEND_REMOTE_URL"
        fi
        cd ..
    fi
    
    # Create changelog for GitHub release
    RELEASE_CHANGELOG="## Version $NEW_VERSION - $CURRENT_DATE

**Version Bump**: $VERSION_BUMP

### Frontend Repository
- **Commit**: [\`${FRONTEND_COMMIT_HASH:0:8}\`]($FRONTEND_WEB_URL/commit/$FRONTEND_COMMIT_HASH)
- **Message**: $FRONTEND_COMMIT_MESSAGE
- **Repository**: $FRONTEND_WEB_URL

### Backend Repository
- **Commit**: [\`${BACKEND_COMMIT_HASH:0:8}\`]($BACKEND_WEB_URL/commit/$BACKEND_COMMIT_HASH)
- **Message**: $BACKEND_COMMIT_MESSAGE
- **Repository**: $BACKEND_WEB_URL

### Deployment Information
- **Deployment Date**: $CURRENT_DATE
- **Version Bump Type**: $VERSION_BUMP
- **Previous Version**: $CURRENT_VERSION
- **New Version**: $NEW_VERSION"

    # Output to file for GitHub Actions
    echo "$RELEASE_CHANGELOG" > release_changelog.md
    
    # Also set as GitHub Actions output (if running in CI)
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "changelog<<EOF" >> "$GITHUB_OUTPUT"
        echo "$RELEASE_CHANGELOG" >> "$GITHUB_OUTPUT"
        echo "EOF" >> "$GITHUB_OUTPUT"
    fi
    
    log_success "Changelog saved to release_changelog.md"
    log_info "Changelog content:"
    echo ""
    echo "$RELEASE_CHANGELOG"
    echo ""
}

# Commit and push version update
commit_version_update() {
    if [ "$TEST_MODE" == "true" ]; then
        log_test "Skipping git commit and push (test mode)"
        log_test "Would commit version update to: $NEW_VERSION"
        log_test "Would update changelog in README.md"
        return
    fi
    
    log_info "Committing and pushing version update..."
    
    # Update changelog before committing
    update_changelog
    
    # Add version file and README to git
    git add version.txt README.md
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        log_warning "No version changes to commit"
        return
    fi
    
    # Create detailed commit message
    COMMIT_MESSAGE="chore: bump version to $NEW_VERSION

- Version bump type: $VERSION_BUMP
- New version: $NEW_VERSION
- Frontend repo: $FRONTEND_REPO_URL
- Backend repo: $BACKEND_REPO_URL
- Updated changelog in README.md with frontend and backend commit info"
    
    # Commit the version update
    git commit -m "$COMMIT_MESSAGE"
    
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
    if [ "$TEST_MODE" == "true" ]; then
        log_test "Running in TEST MODE - no commits or pushes will be made"
    fi
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
    output_changelog_for_release
    
    if [ "$TEST_MODE" == "true" ]; then
        log_test "Test run completed successfully!"
        log_test "Generated version: $NEW_VERSION (not committed)"
        log_test "Projects are ready for Docker build (test only)"
        log_info "No changes were committed to git"
    else
        log_success "Deployment preparation completed successfully!"
        log_info "New version: $NEW_VERSION"
        log_info "Projects are ready for Docker build"
    fi
}

# Run main function
main "$@"
#!/bin/bash

# Deployment preparation script for GitHub CI
# Usage: ./prepare-deployment.sh [patch|minor|major] [--test|--no-commit]
# 
# Arguments:
#   - First argument: Version bump type (patch, minor, major)
#   - Second argument (optional): Mode flag
#     --test or --no-commit: Run in test mode (no commits, no pushes)
#
# Repository Configuration:
#   Configure repositories via environment variables or deploy.config file
#   Format: REPO_NAME=https://github.com/your-org/repo.git
#   Or use deploy.config file with format: repo_name=https://github.com/your-org/repo.git
#   Docker registry configuration is also loaded from deploy.config

# Source script utilities
source "$(dirname "$0")/script-utils.sh"

# Source .env file if it exists
source_env_file

# Load deployment configuration and set up repositories
setup_deployment_config() {
    log_info "Setting up deployment configuration..."
    
    # Try to load from deploy.config first
    if load_deploy_config; then
        log_success "Deployment configuration loaded from deploy.config"
        
        # Validate that we have repositories configured
        if [[ ${#REPO_NAMES[@]} -eq 0 ]]; then
            log_warning "No repositories found in deploy.config, checking environment variables"
            setup_fallback_config
        fi
    else
        log_warning "Could not load deploy.config, using fallback configuration"
        setup_fallback_config
    fi
    
    # Final validation
    validate_deployment_config
}

# Setup fallback configuration from environment variables
setup_fallback_config() {
    # Initialize arrays if not already done
    declare -g -A REPO_URLS
    declare -g -a REPO_NAMES
    declare -g DOCKER_REGISTRY
    
    log_info "Setting up fallback configuration from environment variables"
    
    # Look for environment variables with pattern *_REPO_URL
    for var in $(env | grep '_REPO_URL=' | cut -d'=' -f1); do
        url="${!var}"
        # Extract repo name from variable (remove _REPO_URL suffix)
        name=$(echo "$var" | sed 's/_REPO_URL$//' | tr '[:upper:]' '[:lower:]')
        REPO_URLS["$name"]="$url"
        REPO_NAMES+=("$name")
        log_info "Found repository from env: $name=$url"
    done
    
    # If no environment variables found, use defaults for backward compatibility
    if [[ ${#REPO_NAMES[@]} -eq 0 ]]; then
        log_warning "No repository configuration found, using default frontend/backend setup"
        REPO_URLS["frontend"]="${FRONTEND_REPO_URL:-https://github.com/your-org/frontend-repo.git}"
        REPO_URLS["backend"]="${BACKEND_REPO_URL:-https://github.com/your-org/backend-repo.git}"
        REPO_NAMES=("frontend" "backend")
    fi
    
    # Set default docker registry if not configured
    if [[ -z "${DOCKER_REGISTRY:-}" ]]; then
        DOCKER_REGISTRY="${DOCKER_REGISTRY_ENV:-ghcr.io}"
        log_info "Using default docker registry: $DOCKER_REGISTRY"
    fi
}

# Validate deployment configuration
validate_deployment_config() {
    if [[ ${#REPO_NAMES[@]} -eq 0 ]]; then
        log_error "No repositories configured. Please set up deploy.config or environment variables."
        log_error "Example deploy.config format:"
        log_error "docker_registry=ghcr.io"
        log_error "frontend_image=https://github.com/your-org/frontend.git"
        log_error "backend_image=https://github.com/your-org/backend.git"
        log_error "api_service=https://github.com/your-org/api.git"
        exit 1
    fi
    
    log_info "Configured repositories:"
    for name in "${REPO_NAMES[@]}"; do
        log_info "  - $name: ${REPO_URLS[$name]}"
    done
    
    if [[ -n "${DOCKER_REGISTRY:-}" ]]; then
        log_info "Docker registry: $DOCKER_REGISTRY"
    else
        log_warning "Docker registry not configured, using default: ghcr.io"
        DOCKER_REGISTRY="ghcr.io"
    fi
}

# Parse arguments
VERSION_BUMP="${1:-patch}"
MODE_FLAG="${2:-}"

# Determine if this is a test run
TEST_MODE=false
if [[ "$MODE_FLAG" == "--test" || "$MODE_FLAG" == "--no-commit" ]]; then
    TEST_MODE=true
fi

# Test mode logging function
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
    
    # Use utility function to bump version
    NEW_VERSION=$(bump_version "$CURRENT_VERSION" "$VERSION_BUMP")
    
    echo "$NEW_VERSION" > "$VERSION_FILE"
    log_success "Version updated to: $NEW_VERSION"
}

# Clone repositories
clone_repositories() {
    log_info "Cloning repositories..."
    
    # Remove existing directories if they exist
    for name in "${REPO_NAMES[@]}"; do
        if [ -d "./$name" ]; then
            log_info "Removing existing directory: ./$name"
            rm -rf "./$name"
        fi
    done
    
    # Clone all configured repositories
    for name in "${REPO_NAMES[@]}"; do
        local url="${REPO_URLS[$name]}"
        log_info "Cloning $name repository from: $url"
        
        if git clone "$url" "./$name"; then
            log_success "$name repository cloned successfully"
        else
            log_error "Failed to clone $name repository from: $url"
            exit 1
        fi
    done
}

# Prepare projects for Docker build
prepare_projects() {
    log_info "Preparing projects for Docker build..."
    
    # Prepare each repository
    for name in "${REPO_NAMES[@]}"; do
        if [ -d "./$name" ]; then
            log_info "Preparing $name project for Docker build"
            cd "./$name"
            
            # Verify project structure based on common file patterns
            local project_type="unknown"
            
            # Check for Node.js/JavaScript project
            if [ -f "package.json" ]; then
                project_type="Node.js"
                log_info "Found package.json in $name project ($project_type)"
            fi
            
            # Check for Python project
            if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
                project_type="Python"
                log_info "Found Python dependency files in $name project ($project_type)"
            fi
            
            # Check for Go project
            if [ -f "go.mod" ]; then
                project_type="Go"
                log_info "Found go.mod in $name project ($project_type)"
            fi
            
            # Check for Java/Maven project
            if [ -f "pom.xml" ]; then
                project_type="Maven/Java"
                log_info "Found pom.xml in $name project ($project_type)"
            fi
            
            # Check for Java/Gradle project
            if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
                project_type="Gradle/Java"
                log_info "Found Gradle build files in $name project ($project_type)"
            fi
            
            # Check for .NET project
            if [ -f "*.csproj" ] || [ -f "*.sln" ]; then
                project_type=".NET"
                log_info "Found .NET project files in $name project ($project_type)"
            fi
            
            # Check for Dockerfile
            if [ -f "Dockerfile" ]; then
                log_info "Found Dockerfile in $name project"
            fi
            
            # Check for Docker Compose
            if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
                log_info "Found Docker Compose files in $name project"
            fi
            
            log_info "$name project ready for Docker build (Type: $project_type)"
            cd ..
        else
            log_warning "Directory ./$name not found, skipping preparation"
        fi
    done
    
    log_success "All projects prepared for Docker build"
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
    
    # Start building changelog entry
    local changelog_entry="### Version $NEW_VERSION - $CURRENT_DATE

- **Version**: $NEW_VERSION
- **Type**: $VERSION_BUMP version bump
- **Docker Registry**: ${DOCKER_REGISTRY:-"Not configured"}

"
    
    # Add information for each repository
    for name in "${REPO_NAMES[@]}"; do
        local commit_hash=""
        local commit_message=""
        local web_url=""
        
        if [ -d "./$name" ]; then
            commit_hash=$(cd "./$name" && git rev-parse HEAD 2>/dev/null || echo "unknown")
            commit_message=$(cd "./$name" && get_commit_message)
            web_url=$(get_repo_web_url "./$name")
        fi
        
        # Capitalize first letter of repo name for display
        local display_name="$(tr '[:lower:]' '[:upper:]' <<< ${name:0:1})${name:1}"
        
        changelog_entry+="#### $display_name Repository
- **Commit**: [\`${commit_hash:0:8}\`]($web_url/commit/$commit_hash)
- **Message**: $commit_message

"
    done
    
    changelog_entry+="---
"
    
    # Check if README exists
    if [ ! -f "$README_FILE" ]; then
        log_info "Creating new README.md file..."
        cat > "$README_FILE" << EOF
# Deployment Repository

This repository contains deployment configurations and scripts.

$CHANGELOG_SECTION

$changelog_entry
EOF
    else
        # Check if changelog section exists
        if grep -q "^$CHANGELOG_SECTION" "$README_FILE"; then
            log_info "Updating existing changelog section..."
            # Create a temporary file with the new entry
            TEMP_FILE=$(mktemp)
            
            # Add the new entry after the changelog header
            awk -v entry="$changelog_entry" '
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
            echo "$changelog_entry" >> "$README_FILE"
        fi
    fi
    
    log_success "Changelog updated in README.md"
}

# Output changelog for GitHub Actions release
output_changelog_for_release() {
    log_info "Outputting changelog for GitHub Actions release..."
    
    # Get current date
    CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Start building release changelog
    local release_changelog="## Version $NEW_VERSION - $CURRENT_DATE

**Version Bump**: $VERSION_BUMP

"
    
    # Add information for each repository
    for name in "${REPO_NAMES[@]}"; do
        local commit_hash=""
        local commit_message=""
        local web_url=""
        
        if [ -d "./$name" ]; then
            commit_hash=$(cd "./$name" && git rev-parse HEAD 2>/dev/null || echo "unknown")
            commit_message=$(cd "./$name" && get_commit_message)
            web_url=$(get_repo_web_url "./$name")
        fi
        
        # Capitalize first letter of repo name for display
        local display_name="$(tr '[:lower:]' '[:upper:]' <<< ${name:0:1})${name:1}"
        
        release_changelog+="### $display_name Repository
- **Commit**: [\`${commit_hash:0:8}\`]($web_url/commit/$commit_hash)
- **Message**: $commit_message
- **Repository**: $web_url

"
    done
    
    release_changelog+="### Deployment Information
- **Deployment Date**: $CURRENT_DATE
- **Version Bump Type**: $VERSION_BUMP
- **Previous Version**: $CURRENT_VERSION
- **New Version**: $NEW_VERSION
- **Docker Registry**: ${DOCKER_REGISTRY:-"Not configured"}"

    # Output to file for GitHub Actions
    echo "$release_changelog" > release_changelog.md
    
    # Also set as GitHub Actions output (if running in CI)
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "changelog<<EOF" >> "$GITHUB_OUTPUT"
        echo "$release_changelog" >> "$GITHUB_OUTPUT"
        echo "EOF" >> "$GITHUB_OUTPUT"
        
        # Output docker registry for use in subsequent steps
        echo "docker_registry=${DOCKER_REGISTRY:-ghcr.io}" >> "$GITHUB_OUTPUT"
        echo "version=$NEW_VERSION" >> "$GITHUB_OUTPUT"
    fi
    
    log_success "Changelog saved to release_changelog.md"
    log_info "Changelog content:"
    echo ""
    echo "$release_changelog"
    echo ""
}

# Export deployment configuration for other scripts
export_deployment_config() {
    log_info "Exporting deployment configuration..."
    
    # Create deployment environment file
    cat > deployment.env << EOF
# Deployment configuration generated by prepare-deployment.sh
# Generated on: $(date '+%Y-%m-%d %H:%M:%S')

# Version information
VERSION=$NEW_VERSION
PREVIOUS_VERSION=$CURRENT_VERSION
VERSION_BUMP=$VERSION_BUMP

# Docker registry
DOCKER_REGISTRY=${DOCKER_REGISTRY:-ghcr.io}

# Repository information
EOF

    # Add repository variables
    for name in "${REPO_NAMES[@]}"; do
        local upper_name=$(echo "$name" | tr '[:lower:]' '[:upper:]')
        echo "${upper_name}_REPO_URL=${REPO_URLS[$name]}" >> deployment.env
    done
    
    # Add list of repository names
    echo "REPO_NAMES=${REPO_NAMES[*]}" >> deployment.env
    
    log_success "Deployment configuration exported to deployment.env"
    log_info "Other scripts can source this file to access deployment variables"
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
    
    # Build repository list for commit message
    local repo_list=""
    for name in "${REPO_NAMES[@]}"; do
        local url="${REPO_URLS[$name]}"
        repo_list+="- $name repo: $url"$'\n'
    done
    
    # Create detailed commit message
    COMMIT_MESSAGE="chore: bump version to $NEW_VERSION

- Version bump type: $VERSION_BUMP
- New version: $NEW_VERSION
- Updated changelog in README.md with commit info from all repositories
- Docker registry: ${DOCKER_REGISTRY:-"Not configured"}

Configured repositories:
$repo_list"
    
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
    
    # Load repository configuration first
    setup_deployment_config
    
    validate_version_bump
    manage_version
    clone_repositories
    prepare_projects
    commit_version_update
    output_changelog_for_release
    export_deployment_config
    
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
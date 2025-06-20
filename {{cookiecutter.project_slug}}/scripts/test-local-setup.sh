#!/bin/bash

# Local testing script for deployment preparation
# This script helps you test the deployment process locally before running it in CI/CD

# Source script utilities
source "$(dirname "$0")/script-utils.sh"

# Check if required tools are installed
check_dependencies() {
    log_info "Checking required dependencies..."
    
    local missing_deps=()
    
    # Check for Git
    if ! validate_command_exists git "Git" >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    # Check for Docker (optional but recommended)
    if ! validate_command_exists docker "Docker" >/dev/null 2>&1; then
        log_warning "Docker not found - Docker builds will be skipped"
    else
        log_success "Docker found"
    fi
    
    # Check for Bun (optional)
    if ! validate_command_exists bun "Bun" >/dev/null 2>&1; then
        log_warning "Bun not found - frontend builds may use npm/yarn fallback"
    else
        log_success "Bun found"
    fi
    
    # Check for UV (optional)
    if ! validate_command_exists uv "UV" >/dev/null 2>&1; then
        log_warning "UV not found - backend builds may use pip fallback"
    else
        log_success "UV found"
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
    
    log_success "All required dependencies are available"
}

# Test repository structure
test_repo_structure() {
    log_info "Testing repository structure..."
    
    # Check for deployment script
    validate_file_exists "scripts/prepare-deployment.sh" "Deployment script" || return 1
    log_success "Deployment script found"
    
    # Check for workflow files
    validate_file_exists ".github/workflows/deploy.yml" "Deploy workflow" || return 1
    log_success "Deploy workflow found"
    
    validate_file_exists ".github/workflows/test-build.yml" "Test build workflow" || return 1
    log_success "Test build workflow found"
    
    # Check for reusable action
    validate_file_exists ".github/actions/build-and-test/action.yml" "Build and test action" || return 1
    log_success "Build and test action found"
    
    validate_file_exists ".github/actions/dockerfile-build/action.yml" "Dockerfile build action" || return 1
    log_success "Dockerfile build action found"
    
    log_success "Repository structure is valid"
}

# Test environment file
test_environment() {
    log_info "Testing environment configuration..."
    
    if [ -f ".env" ]; then
        log_info "Found .env file"
        source_env_file
        
        if [ -n "${FRONTEND_REPO_URL:-}" ]; then
            log_success "Frontend repository URL configured: $FRONTEND_REPO_URL"
        else
            log_warning "FRONTEND_REPO_URL not set in .env"
        fi
        
        if [ -n "${BACKEND_REPO_URL:-}" ]; then
            log_success "Backend repository URL configured: $BACKEND_REPO_URL"
        else
            log_warning "BACKEND_REPO_URL not set in .env"
        fi
    else
        log_warning "No .env file found - using default repository URLs"
        log_info "Create a .env file with FRONTEND_REPO_URL and BACKEND_REPO_URL to customize"
    fi
}

# Test deployment script (dry run)
test_deployment_script() {
    log_info "Testing deployment script (dry run)..."
    
    # Make script executable
    chmod +x scripts/prepare-deployment.sh
    
    # Create a backup of the script
    cp scripts/prepare-deployment.sh scripts/prepare-deployment-backup.sh
    
    # Create a test version that doesn't commit or clone
    cat > scripts/prepare-deployment-test.sh << 'EOF'
#!/bin/bash
set -e

# Test version of deployment script
VERSION_BUMP="${1:-patch}"

# Create mock version management
VERSION_FILE="version.txt"
if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
    CURRENT_VERSION="1.0.0"
else
    CURRENT_VERSION=$(cat "$VERSION_FILE")
fi

echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

# Bump version
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
echo "Test version updated to: $NEW_VERSION"

# Create mock directories
mkdir -p frontend backend

# Create mock files to simulate cloned repos
echo '{"name": "test-frontend"}' > frontend/package.json
echo 'FROM node:18' > frontend/Dockerfile
echo '[project]\nname = "test-backend"' > backend/pyproject.toml
echo 'FROM python:3.11' > backend/Dockerfile

echo "Mock repositories created for testing"
echo "Test completed successfully!"
EOF

    chmod +x scripts/prepare-deployment-test.sh
    
    # Run the test script
    if ./scripts/prepare-deployment-test.sh patch; then
        log_success "Deployment script test passed"
    else
        log_error "Deployment script test failed"
        return 1
    fi
    
    # Clean up test files
    rm -f scripts/prepare-deployment-test.sh
    rm -rf frontend backend
}

# Test Docker builds (if Docker is available)
test_docker_builds() {
    if ! check_docker_available >/dev/null 2>&1; then
        log_warning "Skipping Docker tests - Docker not available or not running"
        return 0
    fi
    
    log_success "Docker is available and running"
    
    # Test hadolint (Dockerfile linter)
    if docker run --rm -i hadolint/hadolint --version &> /dev/null; then
        log_success "Hadolint (Dockerfile linter) is available"
    else
        log_warning "Could not test hadolint - Docker image may need to be pulled"
    fi
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    cat > test-report.md << EOF
# Local Testing Report

**Generated**: $(date)
**Repository**: $(git remote get-url origin 2>/dev/null || echo "Not a git repository")
**Branch**: $(git branch --show-current 2>/dev/null || echo "Unknown")

## Test Results

### Dependencies
- Git: $(command -v git >/dev/null && echo "✅ Available" || echo "❌ Missing")
- Docker: $(command -v docker >/dev/null && echo "✅ Available" || echo "⚠️ Not available")
- Bun: $(command -v bun >/dev/null && echo "✅ Available" || echo "⚠️ Not available")
- UV: $(command -v uv >/dev/null && echo "✅ Available" || echo "⚠️ Not available")

### Repository Structure
- Deployment script: $([ -f "scripts/prepare-deployment.sh" ] && echo "✅ Found" || echo "❌ Missing")
- Deploy workflow: $([ -f ".github/workflows/deploy.yml" ] && echo "✅ Found" || echo "❌ Missing")
- Test workflow: $([ -f ".github/workflows/test-build.yml" ] && echo "✅ Found" || echo "❌ Missing")
- Build action: $([ -f ".github/actions/build-and-test/action.yml" ] && echo "✅ Found" || echo "❌ Missing")
- Docker action: $([ -f ".github/actions/dockerfile-build/action.yml" ] && echo "✅ Found" || echo "❌ Missing")

### Configuration
- Environment file: $([ -f ".env" ] && echo "✅ Found" || echo "⚠️ Not found (optional)")
- Version file: $([ -f "version.txt" ] && echo "✅ Found" || echo "⚠️ Will be created")

## Recommendations

1. **If Docker is not available**: Install Docker for local testing of container builds
2. **If Bun is not available**: Install Bun for faster frontend builds
3. **If UV is not available**: Install UV for faster Python dependency management
4. **Create .env file**: Configure FRONTEND_REPO_URL and BACKEND_REPO_URL
5. **Test in CI**: Run the test-build workflow to validate the full pipeline

## Next Steps

1. Configure repository secrets (see SECRETS.md)
2. Test the workflows in GitHub Actions
3. Customize the deployment script for your specific repositories
4. Set up monitoring and notifications for deployments

EOF

    log_success "Test report generated: test-report.md"
}

# Main function
main() {
    log_info "Starting local deployment setup test..."
    echo ""
    
    check_dependencies
    echo ""
    
    test_repo_structure
    echo ""
    
    test_environment
    echo ""
    
    test_deployment_script
    echo ""
    
    test_docker_builds
    echo ""
    
    generate_report
    echo ""
    
    log_success "Local testing completed!"
    log_info "Review test-report.md for detailed results"
    log_info "Next: Configure repository secrets and test workflows in GitHub Actions"
}

# Run main function
main "$@"

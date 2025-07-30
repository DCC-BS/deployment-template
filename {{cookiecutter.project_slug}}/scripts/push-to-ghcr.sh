#!/bin/bash
set -euo pipefail

# Push Docker Image to GitHub Container Registry (GHCR)
# This script can be used locally and in GitHub workflows
# 
# Usage:
#   Local: ./scripts/push-to-ghcr.sh [OPTIONS]
#   GitHub: Called by workflow with environment variables
#
# Required environment variables:
#   GITHUB_TOKEN  - GitHub personal access token or GITHUB_TOKEN
#   IMAGE_NAME    - Base image name (e.g., textmate-backend)
#
# Optional environment variables:
#   GITHUB_REPOSITORY_OWNER - Repository owner (auto-detected if in git repo)
#   GITHUB_ACTOR           - GitHub username (for workflows)
#   ADDITIONAL_TAG         - Additional custom tag
#   DOCKERFILE_PATH        - Path to Dockerfile (default: Dockerfile)
#   WORKING_DIR           - Working directory (default: current directory)
#   SHA_TAG               - Enable SHA-based tag (default: true)

# Source script utilities
source "$(dirname "$0")/script-utils.sh"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Push Docker image to GitHub Container Registry (GHCR).

OPTIONS:
    -h, --help              Show this help message
    -i, --image-name        Image name (required)
    -o, --owner            Repository owner (auto-detected from git)
    -u, --user             GitHub username
    -t, --token            GitHub token
    -d, --dockerfile       Dockerfile path (default: Dockerfile)
    -w, --working-dir      Working directory (default: current)
    --additional-tag       Additional custom tag
    --no-sha-tag          Disable SHA-based tagging
    --dry-run             Show what would be done without executing

ENVIRONMENT VARIABLES:
    GITHUB_TOKEN, IMAGE_NAME, GITHUB_REPOSITORY_OWNER, GITHUB_ACTOR
    ADDITIONAL_TAG, DOCKERFILE_PATH, WORKING_DIR, SHA_TAG

EXAMPLES:
    # Basic usage with environment variables
    export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
    export IMAGE_NAME=textmate-backend
    $0

    # With command line arguments
    $0 -i textmate-backend -t ghp_xxxxxxxxxxxx -o myusername

    # Auto-detect owner from git remote
    $0 -i textmate-backend -t ghp_xxxxxxxxxxxx
EOF
}

# Function to auto-detect repository owner from git remote
detect_repo_owner() {
    get_repo_owner_from_git
}

# Parse command line arguments
DRY_RUN=false
NO_SHA_TAG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -i|--image-name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -o|--owner)
            GITHUB_REPOSITORY_OWNER="$2"
            shift 2
            ;;
        -u|--user)
            GITHUB_ACTOR="$2"
            shift 2
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -d|--dockerfile)
            DOCKERFILE_PATH="$2"
            shift 2
            ;;
        -w|--working-dir)
            WORKING_DIR="$2"
            shift 2
            ;;
        --additional-tag)
            ADDITIONAL_TAG="$2"
            shift 2
            ;;
        --no-sha-tag)
            NO_SHA_TAG=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set defaults
DOCKERFILE_PATH=${DOCKERFILE_PATH:-"Dockerfile"}
WORKING_DIR=${WORKING_DIR:-"."}
SHA_TAG=${SHA_TAG:-"true"}
ADDITIONAL_TAG=${ADDITIONAL_TAG:-""}

# Override SHA_TAG if --no-sha-tag was used
if [[ "$NO_SHA_TAG" == "true" ]]; then
    SHA_TAG="false"
fi

# Auto-detect repository owner if not provided
if [[ -z "${GITHUB_REPOSITORY_OWNER:-}" ]]; then
    if GITHUB_REPOSITORY_OWNER=$(detect_repo_owner); then
        log_info "Auto-detected repository owner: $GITHUB_REPOSITORY_OWNER"
    fi
fi

# Validate required parameters
validate_required_var "IMAGE_NAME" || { show_usage; exit 1; }
validate_required_var "GITHUB_TOKEN" || { show_usage; exit 1; }

if [[ -z "${GITHUB_REPOSITORY_OWNER:-}" ]]; then
    log_error "GITHUB_REPOSITORY_OWNER is required (could not auto-detect from git)"
    show_usage
    exit 1
fi

# Convert repository owner to lowercase (GHCR requirement)
REPOSITORY_OWNER_LOWERCASE=$(echo "$GITHUB_REPOSITORY_OWNER" | tr '[:upper:]' '[:lower:]')

# Use GITHUB_ACTOR if provided, otherwise use repository owner
GITHUB_USER=${GITHUB_ACTOR:-$REPOSITORY_OWNER_LOWERCASE}

# Change to working directory
if [[ "$WORKING_DIR" != "." ]]; then
    log_info "Changing to working directory: $WORKING_DIR"
    cd "$WORKING_DIR"
fi

# Validate Dockerfile exists
validate_file_exists "$DOCKERFILE_PATH" "Dockerfile" || exit 1

# Generate tags
TAGS=()
REGISTRY_PATH="ghcr.io/$REPOSITORY_OWNER_LOWERCASE/$IMAGE_NAME"

# Add latest tag
TAGS+=("$REGISTRY_PATH:latest")

# Add SHA tag if enabled
if [[ "$SHA_TAG" == "true" ]]; then
    SHORT_SHA=$(get_short_sha)
    if [[ "$SHORT_SHA" != "unknown" ]]; then
        TAGS+=("$REGISTRY_PATH:sha-$SHORT_SHA")
        log_info "Adding SHA tag: sha-$SHORT_SHA"
    else
        log_warning "Git not available or not in a git repository, skipping SHA tag"
    fi
fi

# Add additional tag if provided
if [[ -n "$ADDITIONAL_TAG" ]]; then
    TAGS+=("$REGISTRY_PATH:$ADDITIONAL_TAG")
    log_info "Adding additional tag: $ADDITIONAL_TAG"
fi

# Build tag arguments for docker build
TAG_ARGS=""
for tag in "${TAGS[@]}"; do
    TAG_ARGS="$TAG_ARGS -t $tag"
done

log_info "Registry path: $REGISTRY_PATH"
log_info "GitHub user: $GITHUB_USER"
log_info "Tags to be applied: ${TAGS[*]}"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN - Login and push commands that would be executed:"
    echo "docker login ghcr.io -u $GITHUB_USER -p [HIDDEN]"
    for tag in "${TAGS[@]}"; do
        echo "docker push $tag"
    done
    
    # Actually build the image in dry run mode
    log_info "Building Docker image (dry run mode)..."
    if ! docker build $TAG_ARGS -f "$DOCKERFILE_PATH" .; then
        log_error "Docker build failed"
        exit 1
    fi
    log_success "Docker image built successfully (dry run mode)"
    log_info "DRY RUN complete - image built but not pushed"
    exit 0
fi

# Login to GHCR
docker_login_with_retry "ghcr.io" "$GITHUB_USER" "$GITHUB_TOKEN" || exit 1

# Build the image with all tags
log_info "Building Docker image..."
if ! docker build $TAG_ARGS -f "$DOCKERFILE_PATH" .; then
    log_error "Docker build failed"
    exit 1
fi
log_success "Docker image built successfully"

# Install certificates if needed
if [[ -n "${IMAGE_NAME:-}" ]] && declare -f repo_needs_certificates >/dev/null 2>&1; then
    # Load deployment config to check certificate requirements (if not already loaded)
    if [[ -z "${REPO_NAMES:-}" ]] && ! load_deploy_config >/dev/null 2>&1; then
        log_debug "Could not load deployment config, skipping certificate check"
    elif [[ -n "${REPO_NAMES:-}" ]] || load_deploy_config >/dev/null 2>&1; then
        if repo_needs_certificates "$IMAGE_NAME"; then
            log_info "Repository $IMAGE_NAME requires certificate installation"
            
            # Determine certificate install path
            local cert_path="${CERT_INSTALL_PATH:-/usr/local/share/ca-certificates}"
            
            # Install certificates for all tags
            for tag in "${TAGS[@]}"; do
                if ! install_certificates_in_image "$tag" "$cert_path"; then
                    log_error "Failed to install certificates in image: $tag"
                    exit 1
                fi
            done
        else
            log_debug "Repository $IMAGE_NAME does not require certificates"
        fi
    fi
else
    log_debug "Certificate installation not available or IMAGE_NAME not set"
fi

# Push all tags
log_info "Pushing images to ghcr.io..."
for tag in "${TAGS[@]}"; do
    log_info "Pushing: $tag"
    if ! docker push "$tag"; then
        log_error "Failed to push: $tag"
        exit 1
    fi
    log_success "Successfully pushed: $tag"
done

log_success "All images pushed successfully to GitHub Container Registry!"

# Logout for security
docker logout ghcr.io
log_info "Logged out from ghcr.io"

# Ensure script exits with success status
exit 0

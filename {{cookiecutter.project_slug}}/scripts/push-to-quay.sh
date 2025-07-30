#!/bin/bash
set -euo pipefail

# Push Docker Image to Quay.io Registry
# This script can be used locally and in GitHub workflows
# 
# Usage:
#   Local: ./scripts/push-to-quay.sh [OPTIONS]
#   GitHub: Called by workflow with environment variables
#
# Required environment variables:
#   QUAY_USER     - Quay.io username
#   QUAY_PASSWORD - Quay.io password or robot token
#   IMAGE_NAME    - Base image name (e.g., textmate-backend)
#
# Optional environment variables:
#   QUAY_ORGANIZATION - Quay organization name
#   QUAY_TEAM        - Quay team name
#   ADDITIONAL_TAG   - Additional custom tag
#   DOCKERFILE_PATH  - Path to Dockerfile (default: Dockerfile)
#   WORKING_DIR     - Working directory (default: current directory)
#   SHA_TAG         - Enable SHA-based tag (default: true)
#   GITHUB_REPOSITORY_OWNER - Repository owner (for GitHub workflows)

# Source script utilities
source "$(dirname "$0")/script-utils.sh"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Push Docker image to Quay.io registry.

OPTIONS:
    -h, --help              Show this help message
    -i, --image-name        Image name (required)
    -o, --organization      Quay organization
    -t, --team             Quay team
    -u, --user             Quay username
    -p, --password         Quay password/token
    -d, --dockerfile       Dockerfile path (default: Dockerfile)
    -w, --working-dir      Working directory (default: current)
    --additional-tag       Additional custom tag
    --no-sha-tag          Disable SHA-based tagging
    --dry-run             Show what would be done without executing

ENVIRONMENT VARIABLES:
    QUAY_USER, QUAY_PASSWORD, IMAGE_NAME, QUAY_ORGANIZATION, QUAY_TEAM
    ADDITIONAL_TAG, DOCKERFILE_PATH, WORKING_DIR, SHA_TAG

EXAMPLES:
    # Basic usage with environment variables
    export QUAY_USER=myuser
    export QUAY_PASSWORD=mytoken
    export IMAGE_NAME=textmate-backend
    $0

    # With command line arguments
    $0 -i textmate-backend -u myuser -p mytoken -o myorg

    # With team structure
    $0 -i textmate-backend -o myorg -t myteam
EOF
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
        -o|--organization)
            QUAY_ORGANIZATION="$2"
            shift 2
            ;;
        -t|--team)
            QUAY_TEAM="$2"
            shift 2
            ;;
        -u|--user)
            QUAY_USER="$2"
            shift 2
            ;;
        -p|--password)
            QUAY_PASSWORD="$2"
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
QUAY_ORGANIZATION=${QUAY_ORGANIZATION:-""}
QUAY_TEAM=${QUAY_TEAM:-""}
ADDITIONAL_TAG=${ADDITIONAL_TAG:-""}

# Override SHA_TAG if --no-sha-tag was used
if [[ "$NO_SHA_TAG" == "true" ]]; then
    SHA_TAG="false"
fi

# Validate required parameters
validate_required_var "IMAGE_NAME" || { show_usage; exit 1; }
validate_required_var "QUAY_USER" || { show_usage; exit 1; }
validate_required_var "QUAY_PASSWORD" || { show_usage; exit 1; }

# Change to working directory
if [[ "$WORKING_DIR" != "." ]]; then
    log_info "Changing to working directory: $WORKING_DIR"
    cd "$WORKING_DIR"
fi

# Validate Dockerfile exists
validate_file_exists "$DOCKERFILE_PATH" "Dockerfile" || exit 1

# Generate tags
TAGS=()

# Determine registry path based on organization and team
if [[ -n "$QUAY_ORGANIZATION" && -n "$QUAY_TEAM" ]]; then
    REGISTRY_PATH="quay.io/$QUAY_ORGANIZATION/$QUAY_TEAM/$IMAGE_NAME"
elif [[ -n "$QUAY_ORGANIZATION" ]]; then
    REGISTRY_PATH="quay.io/$QUAY_ORGANIZATION/$IMAGE_NAME"
else
    REGISTRY_PATH="quay.io/$IMAGE_NAME"
fi

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
log_info "Tags to be applied: ${TAGS[*]}"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN - Login and push commands that would be executed:"
    echo "docker login quay.io -u $QUAY_USER -p [HIDDEN]"
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

# Login to Quay.io
docker_login_with_retry "quay.io" "$QUAY_USER" "$QUAY_PASSWORD" || exit 1

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
log_info "Pushing images to quay.io..."
for tag in "${TAGS[@]}"; do
    log_info "Pushing: $tag"
    if ! docker push "$tag"; then
        log_error "Failed to push: $tag"
        exit 1
    fi
    log_success "Successfully pushed: $tag"
done

log_success "All images pushed successfully to Quay.io!"

# Logout for security
docker logout quay.io
log_info "Logged out from quay.io"

# Ensure script exits with success status
exit 0

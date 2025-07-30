#!/bin/bash
set -euo pipefail

# Deploy All Images Script
# This script loads the deployment configuration and pushes all configured images
# to the appropriate registry based on the docker_registry setting.
#
# Usage:
#   ./scripts/deploy-all.sh [CONFIG_FILE]
#
# Optional arguments:
#   CONFIG_FILE - Path to deployment config file (default: deploy.config)
#
# The script will:
# 1. Load the deployment configuration using load_deploy_config
# 2. For each repository mapping, call the appropriate push script:
#    - push-to-ghcr.sh when docker_registry is "ghcr"
#    - push-to-quay.sh when docker_registry is "quay"

# Source script utilities
source "$(dirname "$0")/script-utils.sh"

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [CONFIG_FILE]

Deploy all configured images to the appropriate registry.

Options:
    -d, --dry-run      Show what would be deployed without actually deploying
    -h, --help         Show this help message

Arguments:
    CONFIG_FILE    Path to deployment config file (default: deploy.config)

Environment Variables:
    For GHCR (when docker_registry=ghcr):
        GITHUB_TOKEN           - GitHub personal access token
        GITHUB_REPOSITORY_OWNER - Repository owner (optional, auto-detected)
        GITHUB_ACTOR           - GitHub username (optional)

    For Quay (when docker_registry=quay):
        QUAY_USER              - Quay.io username
        QUAY_PASSWORD          - Quay.io password or robot token
        QUAY_ORGANIZATION      - Quay organization name (optional)
        QUAY_TEAM              - Quay team name (optional)

    Common:
        ADDITIONAL_TAG         - Additional custom tag (optional)
        DOCKERFILE_PATH        - Path to Dockerfile (default: Dockerfile)
        WORKING_DIR           - Working directory (default: current directory)
        DRY_RUN               - Set to 'true' for dry run mode (alternative to --dry-run)

Examples:
    # Use default config file
    $0

    # Use custom config file
    $0 /path/to/custom.config

    # Dry run with default config
    $0 --dry-run

    # Dry run with custom config
    $0 --dry-run /path/to/custom.config

    # With environment variables for GHCR
    GITHUB_TOKEN=ghp_xxx $0

    # With environment variables for Quay
    QUAY_USER=myuser QUAY_PASSWORD=mypass $0
EOF
}

# Function to normalize registry name
normalize_registry_name() {
    local registry="$1"
    
    # Convert registry URL/name to normalized form
    case "$registry" in
        ghcr|ghcr.io|github)
            echo "ghcr"
            ;;
        quay|quay.io)
            echo "quay"
            ;;
        *)
            echo "$registry"
            ;;
    esac
}

# Function to validate registry-specific environment variables
validate_registry_env() {
    local registry="$1"
    local normalized_registry=$(normalize_registry_name "$registry")
    
    case "$normalized_registry" in
        ghcr)
            if [[ -z "${GITHUB_TOKEN:-}" ]]; then
                log_error "GITHUB_TOKEN environment variable is required for GHCR registry"
                log_info "Please set GITHUB_TOKEN to your GitHub personal access token"
                return 1
            fi
            ;;
        quay)
            if [[ -z "${QUAY_USER:-}" ]] || [[ -z "${QUAY_PASSWORD:-}" ]]; then
                log_error "QUAY_USER and QUAY_PASSWORD environment variables are required for Quay registry"
                log_info "Please set QUAY_USER and QUAY_PASSWORD for Quay.io authentication"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported docker registry: $registry"
            log_info "Supported registries: ghcr, ghcr.io, quay, quay.io"
            return 1
            ;;
    esac
    
    return 0
}

# Function to push image to GHCR
push_to_ghcr() {
    local image_name="$1"
    local script_dir="$(dirname "$0")"
    
    log_info "Pushing $image_name to GitHub Container Registry..."
    
    # Set IMAGE_NAME and WORKING_DIR environment variables for the push script
    export IMAGE_NAME="$image_name"
    export WORKING_DIR="$image_name"
    
    # Call push-to-ghcr.sh script with dry-run flag if needed
    local push_cmd="$script_dir/push-to-ghcr.sh"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        push_cmd="$push_cmd --dry-run"
    fi
    
    if ! $push_cmd; then
        log_error "Failed to push $image_name to GHCR"
        return 1
    fi
    
    log_success "Successfully pushed $image_name to GHCR"
    return 0
}

# Function to push image to Quay
push_to_quay() {
    local image_name="$1"
    local script_dir="$(dirname "$0")"
    
    log_info "Pushing $image_name to Quay.io..."
    
    # Set IMAGE_NAME and WORKING_DIR environment variables for the push script
    export IMAGE_NAME="$image_name"
    export WORKING_DIR="$image_name"
    
    # Call push-to-quay.sh script with dry-run flag if needed
    local push_cmd="$script_dir/push-to-quay.sh"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        push_cmd="$push_cmd --dry-run"
    fi
    
    if ! $push_cmd; then
        log_error "Failed to push $image_name to Quay"
        return 1
    fi
    
    log_success "Successfully pushed $image_name to Quay"
    return 0
}

# Main deployment function
deploy_all() {
    local config_file="${1:-deploy.config}"
    
    log_info "Starting deployment of all configured images..."
    log_info "Configuration file: $config_file"
    
    # Load deployment configuration
    if ! load_deploy_config "$config_file"; then
        log_error "Failed to load deployment configuration"
        exit 1
    fi
    
    # Check if we have any repositories configured
    if [[ ${#REPO_NAMES[@]} -eq 0 ]]; then
        log_warning "No repository mappings found in configuration"
        log_info "Please check your configuration file: $config_file"
        exit 0
    fi
    
    # Check if docker registry is configured
    if [[ -z "$DOCKER_REGISTRY" ]]; then
        log_error "Docker registry not configured in $config_file"
        log_info "Please set docker_registry=ghcr or docker_registry=quay"
        exit 1
    fi
    
    # Validate registry-specific environment variables
    local normalized_registry=$(normalize_registry_name "$DOCKER_REGISTRY")
    if ! validate_registry_env "$DOCKER_REGISTRY"; then
        exit 1
    fi
    
    log_info "Using docker registry: $DOCKER_REGISTRY (normalized: $normalized_registry)"
    log_info "Found ${#REPO_NAMES[@]} repository mapping(s)"
    
    # Check for certificate requirements
    local cert_repos=()
    for repo_name in "${REPO_NAMES[@]}"; do
        if repo_needs_certificates "$repo_name"; then
            cert_repos+=("$repo_name")
        fi
    done
    
    if [[ ${#cert_repos[@]} -gt 0 ]]; then
        log_info "Repositories requiring certificate installation: ${cert_repos[*]}"
        if [[ -n "${CERT_INSTALL_PATH:-}" ]]; then
            log_info "Certificate install path: $CERT_INSTALL_PATH"
        else
            log_info "Certificate install path: /usr/local/share/ca-certificates (default)"
        fi
        
        # Check if assets directory exists and has certificates
        local assets_dir="./assets"
        if [[ -d "$assets_dir" ]]; then
            local cert_files
            cert_files=$(get_certificate_files "$assets_dir" 2>/dev/null || echo "")
            if [[ -n "$cert_files" ]]; then
                log_info "Certificate files found in assets directory:"
                echo "$cert_files" | while read -r cert_file; do
                    log_info "  - $(basename "$cert_file")"
                done
            else
                log_warning "No certificate files found in assets directory"
                log_warning "Repositories requiring certificates: ${cert_repos[*]}"
                log_warning "Please add certificate files to the assets directory"
            fi
        else
            log_warning "Assets directory not found, but repositories need certificates: ${cert_repos[*]}"
        fi
    else
        log_info "No repositories require certificate installation"
    fi

    # Process each repository mapping
    for repo_name in "${REPO_NAMES[@]}"; do
        local repo_url="${REPO_URLS[$repo_name]}"
        
        log_info "Processing repository mapping: $repo_name -> $repo_url"
        
        # Deploy based on registry type
        local normalized_registry=$(normalize_registry_name "$DOCKER_REGISTRY")
        case "$normalized_registry" in
            ghcr)
                if ! push_to_ghcr "$repo_name"; then
                    log_error "Failed to deploy $repo_name - exiting immediately"
                    exit 1
                fi
                ;;
            quay)
                if ! push_to_quay "$repo_name"; then
                    log_error "Failed to deploy $repo_name - exiting immediately"
                    exit 1
                fi
                ;;
            *)
                log_error "Unsupported registry: $DOCKER_REGISTRY"
                log_error "Failed to deploy $repo_name - exiting immediately"
                exit 1
                ;;
        esac
        
        echo  # Add spacing between deployments
    done
    
    # Report deployment summary
    log_success "All images deployed successfully!"
    exit 0
}

# Parse command line arguments
DRY_RUN="${DRY_RUN:-false}"
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$CONFIG_FILE" ]]; then
                CONFIG_FILE="$1"
            else
                log_error "Multiple config files specified"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Export DRY_RUN so it's available to called scripts
export DRY_RUN

# Call deploy_all with the config file (or default if not specified)
deploy_all "${CONFIG_FILE:-deploy.config}"

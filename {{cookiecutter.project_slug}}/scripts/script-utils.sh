#!/bin/bash

# Script Utilities Library
# This file contains common functions and utilities used across deployment scripts
# 
# Usage: Source this file in your scripts:
#   source "$(dirname "$0")/script-utils.sh"
#
# Available functions:
#   - Logging: log_info, log_success, log_warning, log_error, log_debug
#   - Validation: validate_required_var, validate_file_exists, validate_command_exists
#   - Git utilities: get_repo_owner_from_git, get_short_sha, get_commit_message
#   - Docker utilities: check_docker_available, docker_login_with_retry
#   - Version utilities: parse_version, bump_version
#   - Environment: source_env_file, load_deploy_config

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m' # No Color

# Global variables for logging configuration
SCRIPT_UTILS_DEBUG=${SCRIPT_UTILS_DEBUG:-false}
SCRIPT_UTILS_QUIET=${SCRIPT_UTILS_QUIET:-false}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Print info message
log_info() {
    if [[ "$SCRIPT_UTILS_QUIET" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1" >&2
    fi
}

# Print success message
log_success() {
    if [[ "$SCRIPT_UTILS_QUIET" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
    fi
}

# Print warning message
log_warning() {
    if [[ "$SCRIPT_UTILS_QUIET" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1" >&2
    fi
}

# Print error message
log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Print debug message (only if debug mode is enabled)
log_debug() {
    if [[ "$SCRIPT_UTILS_DEBUG" == "true" ]]; then
        echo -e "${GRAY}[DEBUG]${NC} $1" >&2
    fi
}

# Print a separator line
log_separator() {
    if [[ "$SCRIPT_UTILS_QUIET" != "true" ]]; then
        echo -e "${CYAN}$( printf '=%.0s' {1..80} )${NC}" >&2
    fi
}

# Print a section header
log_section() {
    if [[ "$SCRIPT_UTILS_QUIET" != "true" ]]; then
        echo "" >&2
        echo -e "${CYAN}>>> $1 <<<${NC}" >&2
        echo "" >&2
    fi
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate that a required variable is set
validate_required_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    
    if [[ -z "$var_value" ]]; then
        log_error "Required variable '$var_name' is not set"
        return 1
    fi
    
    log_debug "Variable '$var_name' is set"
    return 0
}

# Validate that a file exists
validate_file_exists() {
    local file_path="$1"
    local description="${2:-File}"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "$description not found: $file_path"
        return 1
    fi
    
    log_debug "$description found: $file_path"
    return 0
}

# Validate that a directory exists
validate_dir_exists() {
    local dir_path="$1"
    local description="${2:-Directory}"
    
    if [[ ! -d "$dir_path" ]]; then
        log_error "$description not found: $dir_path"
        return 1
    fi
    
    log_debug "$description found: $dir_path"
    return 0
}

# Validate that a command exists
validate_command_exists() {
    local command_name="$1"
    local description="${2:-Command}"
    
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_error "$description '$command_name' not found in PATH"
        return 1
    fi
    
    log_debug "$description '$command_name' is available"
    return 0
}

# =============================================================================
# GIT UTILITIES
# =============================================================================

# Auto-detect repository owner from git remote
get_repo_owner_from_git() {
    if ! validate_command_exists git "Git" >/dev/null 2>&1; then
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_debug "Not in a git repository"
        return 1
    fi
    
    # Try to get owner from origin remote
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    if [[ -n "$remote_url" ]]; then
        # Handle both SSH and HTTPS formats
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    fi
    
    log_debug "Could not determine repository owner from git remote"
    return 1
}

# Get short SHA of current commit
get_short_sha() {
    if validate_command_exists git "Git" >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        git rev-parse --short HEAD 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Get commit message of current commit
get_commit_message() {
    if validate_command_exists git "Git" >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        git log -1 --pretty=format:'%s' 2>/dev/null || echo "No commit message"
    else
        echo "No commit message"
    fi
}

# Get web URL for a git repository
get_repo_web_url() {
    local repo_path="${1:-.}"
    
    if [[ ! -d "$repo_path" ]]; then
        echo ""
        return 1
    fi
    
    local original_dir="$PWD"
    cd "$repo_path"
    
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    
    local web_url=""
    if [[ $remote_url =~ git@github\.com:(.+)\.git ]]; then
        local repo_path="${BASH_REMATCH[1]}"
        web_url="https://github.com/$repo_path"
    elif [[ $remote_url =~ https://github\.com/(.+)\.git ]]; then
        local repo_path="${BASH_REMATCH[1]}"
        web_url="https://github.com/$repo_path"
    else
        web_url="$remote_url"
    fi
    
    cd "$original_dir"
    echo "$web_url"
}

# =============================================================================
# DOCKER UTILITIES
# =============================================================================

# Check if Docker is available and running
check_docker_available() {
    if ! validate_command_exists docker "Docker" >/dev/null 2>&1; then
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    log_debug "Docker is available and running"
    return 0
}

# Docker login with retry mechanism
docker_login_with_retry() {
    local registry="$1"
    local username="$2"
    local password="$3"
    local max_attempts="${4:-3}"
    
    for attempt in $(seq 1 $max_attempts); do
        log_debug "Docker login attempt $attempt/$max_attempts for $registry"
        
        if echo "$password" | docker login "$registry" -u "$username" --password-stdin >/dev/null 2>&1; then
            log_success "Successfully logged in to $registry"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Login attempt $attempt failed, retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    log_error "Failed to login to $registry after $max_attempts attempts"
    return 1
}

# =============================================================================
# VERSION UTILITIES
# =============================================================================

# Parse semantic version into components
parse_version() {
    local version="$1"
    local major minor patch extra
    
    IFS='.' read -r major minor patch extra <<< "$version"
    
    # Validate and normalize version components
    if [[ ! "$major" =~ ^[0-9]+$ ]]; then
        log_warning "Invalid major version '$major', defaulting to 1"
        major=1
    fi
    
    if [[ ! "$minor" =~ ^[0-9]+$ ]]; then
        log_warning "Invalid minor version '$minor', defaulting to 0"
        minor=0
    fi
    
    if [[ ! "$patch" =~ ^[0-9]+$ ]]; then
        log_warning "Invalid patch version '$patch', defaulting to 0"
        patch=0
    fi
    
    # Warn if there are extra version components
    if [[ -n "$extra" ]]; then
        log_warning "Version has extra components beyond major.minor.patch, normalizing to $major.$minor.$patch"
    fi
    
    echo "$major.$minor.$patch"
}

# Bump version according to semver rules
bump_version() {
    local current_version="$1"
    local bump_type="$2"
    
    # Parse current version
    local normalized_version
    normalized_version=$(parse_version "$current_version")
    
    IFS='.' read -r major minor patch <<< "$normalized_version"
    
    # Bump version based on type
    case "$bump_type" in
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
        *)
            log_error "Invalid bump type: $bump_type (must be major, minor, or patch)"
            return 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# =============================================================================
# ENVIRONMENT UTILITIES
# =============================================================================

# Source .env file if it exists
source_env_file() {
    local env_file="${1:-.env}"
    
    if [[ -f "$env_file" ]]; then
        log_debug "Sourcing environment file: $env_file"
        # shellcheck source=/dev/null
        source "$env_file"
        log_info "Environment file loaded: $env_file"
    else
        log_debug "Environment file not found: $env_file"
    fi
}

# Load deployment configuration from deploy.config file
# This function loads all variables from deploy.config and makes them available
# Returns arrays for repository configuration parsing
load_deploy_config() {
    local config_file="${1:-deploy.config}"
    
    # Use absolute path if relative path is provided
    if [[ "$config_file" != /* ]]; then
        # If called from scripts directory, look in parent directory for deploy.config
        if [[ "$(basename "$(pwd)")" == "scripts" ]] && [[ "$config_file" == "deploy.config" ]]; then
            config_file="../$config_file"
        fi
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Deployment configuration file not found: $config_file"
        return 1
    fi
    
    log_info "Loading deployment configuration from $config_file..."
    
    # Initialize global arrays for repository configuration
    declare -g -A REPO_URLS
    declare -g -a REPO_NAMES
    declare -g DOCKER_REGISTRY=""
    
    # Clear arrays in case function is called multiple times
    REPO_URLS=()
    REPO_NAMES=()
    
    # Read configuration file and process variables
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Process the variable
        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            # Export the variable for general use
            export "$key"="$value"
            log_debug "Loaded: $key=$value"
            
            # Handle special variables
            if [[ "$key" == "docker_registry" ]]; then
                DOCKER_REGISTRY="$value"
                log_debug "Set DOCKER_REGISTRY to: $DOCKER_REGISTRY"
            else
                # Check if the value looks like a repository URL
                if [[ "$value" =~ ^https?://.*\.git$ ]] || [[ "$value" =~ ^git@ ]] || [[ "$value" =~ github\.com|gitlab\.com|bitbucket\.org ]]; then
                    REPO_URLS["$key"]="$value"
                    REPO_NAMES+=("$key")
                    log_debug "Added repository: $key=$value"
                fi
            fi
        fi
    done < "$config_file"
    
    log_success "Deployment configuration loaded successfully"
    log_info "Found ${#REPO_NAMES[@]} repositories"
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        log_info "Docker registry configured: $DOCKER_REGISTRY"
    else
        log_info "Docker registry: not configured"
    fi
    
    return 0
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Initialize script utilities (called automatically when sourced)
init_script_utils() {
    log_debug "Script utilities library loaded"
    
    # Set default error handling if not already set
    if [[ ! "$-" =~ e ]]; then
        log_debug "Setting 'set -e' for error handling"
        set -e
    fi
}

# Auto-initialize when sourced
init_script_utils

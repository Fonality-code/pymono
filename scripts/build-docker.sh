#!/bin/bash

# Docker Build and Push Script for Wayfinder Monorepo
# Usage: ./scripts/build-docker.sh [options] [app_name] [tag]
# Options: -p/--push to push to GHCR, -h/--help for usage

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
APP_NAME=""
TAG="1.0"
PUSH_IMAGE=false
REGISTRY="ghcr.io"
REPO_NAME=$(basename $(git rev-parse --show-toplevel) 2>/dev/null || echo "pymono")
GITHUB_USERNAME="fonality-code"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--push)
            PUSH_IMAGE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$APP_NAME" ]]; then
                APP_NAME="$1"
            elif [[ "$TAG" == "1.0" ]]; then
                TAG="$1"
            fi
            shift
            ;;
    esac
done

# Function to show usage
show_usage() {
    echo "Usage: $0 [options] [app_name] [tag]"
    echo ""
    echo "Options:"
    echo "  -p, --push    Push the image to GHCR after building"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Parameters:"
    echo "  app_name  - Name of the app to build (optional, will show menu if not provided)"
    echo "  tag       - Docker tag to use (default: '1.0')"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive app selection"
    echo "  $0 api               # Build api with '1.0' tag"
    echo "  $0 api dev           # Build api with 'dev' tag"
    echo "  $0 -p api prod       # Build and push api with 'prod' tag"
    echo "  $0 --push api        # Build and push api with '1.0' tag"
    echo ""
}

# Function to find available apps
find_apps() {
    local apps=()

    # Check if apps directory exists
    if [[ ! -d "apps" ]]; then
        return 1
    fi

    for dockerfile in apps/*/Dockerfile; do
        # Skip if no Dockerfiles found (glob didn't match)
        [[ -f "$dockerfile" ]] || continue

        local app_name=$(basename "$(dirname "$dockerfile")")
        apps+=("$app_name")
    done

    # Sort apps alphabetically
    printf '%s\n' "${apps[@]}" | sort
}

# Function to select app interactively
select_app() {
    local apps=($(find_apps))

    if [[ ${#apps[@]} -eq 0 ]]; then
        print_error "No apps with Dockerfiles found in apps/ directory"
        exit 1
    fi

    if [[ ${#apps[@]} -eq 1 ]]; then
        echo "${apps[0]}"
        return
    fi

    echo "Available apps:" >&2
    for i in "${!apps[@]}"; do
        echo "  $((i+1)). ${apps[$i]}" >&2
    done
    echo "  a. All apps" >&2
    echo "" >&2

    while true; do
        read -p "Select an app (1-${#apps[@]} or 'a' for all): " choice

        if [[ "$choice" == "a" || "$choice" == "A" ]]; then
            echo "all"
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#apps[@]}" ]]; then
            echo "${apps[$((choice-1))]}"
            return
        else
            print_warning "Invalid selection. Please try again."
        fi
    done
}

# Function to prompt user for tag confirmation/change
prompt_tag_change() {
    echo ""
    print_status "Current tag: $TAG"
    read -p "Do you want to change the tag? (y/N): " change_tag

    if [[ "$change_tag" =~ ^[Yy]$ ]]; then
        read -p "Enter new tag: " new_tag
        if [[ -n "$new_tag" ]]; then
            TAG="$new_tag"
            print_status "Tag updated to: $TAG"
        else
            print_warning "No tag entered, keeping current tag: $TAG"
        fi
    fi
}

# Function to build a single app
build_app() {
    local app=$1
    local tag=$2

    print_status "Building app: $app"

    # Check if Dockerfile exists
    if [[ ! -f "apps/$app/Dockerfile" ]]; then
        print_error "Dockerfile not found for app: $app"
        return 1
    fi

    # Build the image
    local image_name="$REPO_NAME/$app:$tag"
    print_status "Building image: $image_name"

    if docker build -t "$image_name" -f "apps/$app/Dockerfile" .; then
        print_success "Successfully built: $image_name"

        # Show image size
        local size=$(docker images "$image_name" --format "table {{.Size}}" | tail -n 1)
        print_status "Image size: $size"

        # Push to GHCR if requested
        if [[ "$PUSH_IMAGE" == true ]]; then
            echo ""
            if ! push_image "$app" "$tag"; then
                return 1
            fi
        fi

        # Option to run the container
        echo ""
        read -p "Do you want to run the container? (y/N): " run_container
        if [[ "$run_container" =~ ^[Yy]$ ]]; then
            print_status "Running container..."
            docker run --rm -p 8000:8000 "$image_name"
        fi

        return 0
    else
        print_error "Failed to build: $image_name"
        return 1
    fi
}

# Function to push image to GHCR
push_image() {
    local app=$1
    local tag=$2
    local local_image="$REPO_NAME/$app:$tag"
    local remote_image="$REGISTRY/$GITHUB_USERNAME/$REPO_NAME/$app:$tag"

    print_status "Preparing to push image to GHCR..."

    # Check if local image exists
    if ! docker image inspect "$local_image" >/dev/null 2>&1; then
        print_error "Local image '$local_image' not found. Build the image first."
        return 1
    fi

    # Check if user is logged into GHCR
    if ! docker info 2>/dev/null | grep -q "$REGISTRY"; then
        print_warning "Not logged into GHCR. You need to login first."
        echo ""
        echo "To push to GHCR, you need to:"
        echo "1. Create a GitHub Personal Access Token with 'write:packages' scope"
        echo "2. Login using: echo \$GITHUB_TOKEN | docker login $REGISTRY -u $GITHUB_USERNAME --password-stdin"
        echo ""
        read -p "Have you already logged in? (y/N): " logged_in
        if [[ ! "$logged_in" =~ ^[Yy]$ ]]; then
            print_error "Please login to GHCR first and try again"
            return 1
        fi
    fi

    # Tag the image for GHCR
    print_status "Tagging image for GHCR: $remote_image"
    if ! docker tag "$local_image" "$remote_image"; then
        print_error "Failed to tag image for GHCR"
        return 1
    fi

    # Push the image
    print_status "Pushing image to GHCR: $remote_image"
    if docker push "$remote_image"; then
        print_success "Successfully pushed: $remote_image"

        # Show the package URL
        print_status "Package URL: https://github.com/$GITHUB_USERNAME/packages/container/$REPO_NAME%2F$app"

        return 0
    else
        print_error "Failed to push: $remote_image"
        return 1
    fi
}

# Function to validate app name
validate_app() {
    local app=$1
    local apps=($(find_apps))

    # Check if app exists
    for valid_app in "${apps[@]}"; do
        if [[ "$app" == "$valid_app" ]]; then
            return 0
        fi
    done

    print_error "App '$app' not found. Available apps: ${apps[*]}"
    return 1
}

# Main script
main() {
    # Check if we're in the right directory
    if [[ ! -d "apps" ]]; then
        print_error "This script must be run from the repository root directory"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running or not accessible"
        exit 1
    fi

    # Select app if not provided
    if [[ -z "$APP_NAME" ]]; then
        APP_NAME=$(select_app)
    fi

    # Validate the app name if not "all"
    if [[ "$APP_NAME" != "all" ]] && ! validate_app "$APP_NAME"; then
        exit 1
    fi

    # Prompt user to change tag if desired
    prompt_tag_change

    print_status "Repository: $REPO_NAME"
    print_status "Tag: $TAG"
    if [[ "$PUSH_IMAGE" == true ]]; then
        print_status "Push to GHCR: enabled"
    fi
    echo ""

    # Build apps
    if [[ "$APP_NAME" == "all" ]]; then
        local apps=($(find_apps))
        local failed_builds=()

        for app in "${apps[@]}"; do
            echo ""
            print_status "Building app $app ($(echo ${apps[@]} | tr ' ' '\n' | grep -n "^$app$" | cut -d: -f1)/${#apps[@]})"
            echo "----------------------------------------"

            if ! build_app "$app" "$TAG"; then
                failed_builds+=("$app")
            fi
        done

        echo ""
        echo "========================================"
        print_status "Build Summary"
        echo "========================================"

        if [[ ${#failed_builds[@]} -eq 0 ]]; then
            print_success "All apps built successfully!"
        else
            print_error "Failed builds: ${failed_builds[*]}"
            exit 1
        fi
    else
        build_app "$APP_NAME" "$TAG"
    fi
}

# Run main function
main "$@"

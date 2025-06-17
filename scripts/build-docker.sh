#!/bin/bash

# Local Docker Build Script
# Usage: ./scripts/build-docker.sh [app_name] [tag]

set -e

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
APP_NAME=${1:-""}
TAG=${2:-"local"}
REGISTRY="ghcr.io"
REPO_NAME=$(basename $(git rev-parse --show-toplevel) 2>/dev/null || echo "pymono")

# Function to show usage
show_usage() {
    echo "Usage: $0 [app_name] [tag]"
    echo ""
    echo "Parameters:"
    echo "  app_name  - Name of the app to build (optional, will show menu if not provided)"
    echo "  tag       - Docker tag to use (default: 'local')"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive app selection"
    echo "  $0 api               # Build api with 'local' tag"
    echo "  $0 api dev           # Build api with 'dev' tag"
    echo ""
}

# Function to find available apps
find_apps() {
    local apps=()
    for dockerfile in apps/*/Dockerfile; do
        if [[ -f "$dockerfile" ]]; then
            app_name=$(dirname "$dockerfile" | sed 's|apps/||')
            apps+=("$app_name")
        fi
    done
    echo "${apps[@]}"
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

    echo "Available apps:"
    for i in "${!apps[@]}"; do
        echo "  $((i+1)). ${apps[$i]}"
    done
    echo "  a. All apps"
    echo ""

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

    # Handle help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi

    # Select app if not provided
    if [[ -z "$APP_NAME" ]]; then
        APP_NAME=$(select_app)
    fi

    print_status "Repository: $REPO_NAME"
    print_status "Tag: $TAG"
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

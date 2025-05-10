#!/usr/bin/env bash
set -euo pipefail

# Script to run version-generator tests in an Ubuntu Docker container
# This more closely matches the GitHub Actions runner environment

# Define Docker image to use (Ubuntu slim is much smaller)
DOCKER_IMAGE="ubuntu:22.04"

# Pull the Docker image first
echo "Pulling Docker image $DOCKER_IMAGE..."
docker pull $DOCKER_IMAGE

echo "Running tests in Docker container using $DOCKER_IMAGE..."

# Run the tests in Docker
docker run --rm -v "$(pwd):/app" -w /app $DOCKER_IMAGE bash -c "
    # Install dependencies
    apt-get update && apt-get install -y git jq

    # Make scripts executable
    chmod +x ./generate-version.sh ./test-generate-version.sh

    # Run the tests
    ./test-generate-version.sh
"

# Check exit code
if [ $? -eq 0 ]; then
    echo "Tests passed successfully in Docker environment!"
else
    echo "Tests failed in Docker environment!"
    exit 1
fi

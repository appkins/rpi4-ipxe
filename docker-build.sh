#!/bin/bash

# Docker-based build script for Raspberry Pi 4 UEFI firmware with RedfishClient
# Uses TianoCore Ubuntu 22 build container

set -e

# Get the absolute path of the current directory
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Docker-based build for Raspberry Pi 4 UEFI firmware with RedfishClient..."
echo "Workspace: ${WORKSPACE_DIR}"

# Run the build inside the TianoCore container
docker run -it --rm \
    --privileged \
    -p 5000:5000 \
    -v "${WORKSPACE_DIR}":"/home/edk2" \
    -w "/home/edk2" \
    -e EDK2_DOCKER_USER_HOME="/home/edk2" \
    -e WORKSPACE="/home/edk2" \
    -e DEBUGMACROCHECKBUILDPLUGIN=SKIP \
    --platform linux/arm64 \
    ghcr.io/tianocore/containers/fedora-41-build:latest \
    bash -c '
        set -e
        echo "=== Setting up build environment in container ==="
        
        # Fix Git ownership issue for all repositories
        git config --global --add safe.directory /home/edk2
        git config --global --add safe.directory /home/edk2/edk2
        git config --global --add safe.directory /home/edk2/platforms
        git config --global --add safe.directory /home/edk2/non-osi
        git config --global --add safe.directory /home/edk2/redfish-client
        git config --global --add safe.directory "*"
        
        # Skip pip upgrade and use existing tools
        echo "Using existing EDK2 tools..."
        
        # Activate Poetry environment and run build steps
        echo "=== Running Stuart setup ==="
        stuart_setup -c RpiPlatformBuild.py
        
        echo "=== Running Stuart update ==="
        stuart_update -c RpiPlatformBuild.py
        
        echo "=== Building BaseTools ==="
        # BaseTools must be built for the host architecture (x86_64), not target (ARM64)
        unset GCC5_AARCH64_PREFIX
        unset GCC_AARCH64_PREFIX
        make -C edk2/BaseTools
        
        # Restore cross-compilation environment for target build
        export GCC5_AARCH64_PREFIX=/usr/bin/aarch64-linux-gnu-
        export GCC_AARCH64_PREFIX=/usr/bin/aarch64-linux-gnu-
        
        echo "=== Running Stuart build ==="
        stuart_build -c RpiPlatformBuild.py
        
        echo "=== Build completed successfully ==="
        echo "Firmware file should be available at: Build/RPi4/RELEASE_GCC5/FV/RPI_EFI.fd"
    '

echo "Docker build completed!"

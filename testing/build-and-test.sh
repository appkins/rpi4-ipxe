#!/bin/bash

# Comprehensive build and test script for RPi4 UEFI with Redfish support
# This script builds the firmware and sets up the testing environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
TESTING_DIR="${SCRIPT_DIR}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --build        Build the UEFI firmware with Redfish support"
    echo "  -s, --simulator    Set up the Redfish simulator"
    echo "  -t, --test         Run Redfish connectivity tests"
    echo "  -c, --clean        Clean build artifacts"
    echo "  -a, --all          Run all steps (build, setup simulator, test)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all           # Complete build and test cycle"
    echo "  $0 --build         # Just build the firmware"
    echo "  $0 --simulator     # Just set up the simulator"
    echo "  $0 --test          # Just run tests (requires simulator to be running)"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    cd "${PROJECT_ROOT}"
    if ! make check-deps &> /dev/null; then
        log_error "Prerequisites check failed. Please install required dependencies."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Function to build firmware
build_firmware() {
    log_info "Building UEFI firmware with Redfish support..."

    cd "${PROJECT_ROOT}"

    # Clean any previous builds if requested
    if [[ "${CLEAN_BUILD:-false}" == "true" ]]; then
        log_info "Cleaning previous build artifacts..."
        make clean
    fi

    # Build the firmware
    log_info "Starting build process..."
    if make build; then
        log_success "Firmware build completed successfully"

        # Show build artifacts
        if [[ -f "Build/RPi4/RELEASE_GCC5/FV/RPI_EFI.fd" ]]; then
            FIRMWARE_SIZE=$(du -h "Build/RPi4/RELEASE_GCC5/FV/RPI_EFI.fd" | cut -f1)
            log_info "Firmware size: ${FIRMWARE_SIZE}"
        fi

        if [[ -f "RPi4_UEFI_Firmware_"*.zip ]]; then
            ARCHIVE_SIZE=$(du -h RPi4_UEFI_Firmware_*.zip | cut -f1)
            log_info "Archive size: ${ARCHIVE_SIZE}"
        fi
    else
        log_error "Firmware build failed"
        exit 1
    fi
}

# Function to setup Redfish simulator
setup_simulator() {
    log_info "Setting up Redfish Profile Simulator..."

    cd "${TESTING_DIR}"
    if ./setup-redfish-simulator.sh; then
        log_success "Redfish simulator setup completed"
    else
        log_error "Redfish simulator setup failed"
        exit 1
    fi
}

# Function to start simulator in background
start_simulator() {
    log_info "Starting Redfish simulator..."

    local simulator_dir="${TESTING_DIR}/redfish-simulator"
    if [[ ! -d "${simulator_dir}" ]]; then
        log_error "Simulator not found. Run setup first."
        exit 1
    fi

    cd "${simulator_dir}"

    # Check if simulator is already running
    if curl -s http://localhost:5000/redfish/v1/ &> /dev/null; then
        log_info "Simulator is already running"
        return 0
    fi

    # Start simulator in background
    nohup ./start-rpi4-simulator.sh > simulator.log 2>&1 &
    local sim_pid=$!

    # Wait for simulator to start
    log_info "Waiting for simulator to start..."
    local retry_count=0
    while ! curl -s http://localhost:5000/redfish/v1/ &> /dev/null && [[ $retry_count -lt 30 ]]; do
        sleep 1
        ((retry_count++))
    done

    if curl -s http://localhost:5000/redfish/v1/ &> /dev/null; then
        log_success "Simulator started successfully (PID: ${sim_pid})"
        echo "${sim_pid}" > simulator.pid
    else
        log_error "Failed to start simulator"
        exit 1
    fi
}

# Function to stop simulator
stop_simulator() {
    local simulator_dir="${TESTING_DIR}/redfish-simulator"
    if [[ -f "${simulator_dir}/simulator.pid" ]]; then
        local sim_pid=$(cat "${simulator_dir}/simulator.pid")
        if kill "${sim_pid}" 2>/dev/null; then
            log_info "Simulator stopped (PID: ${sim_pid})"
            rm -f "${simulator_dir}/simulator.pid"
        fi
    fi
}

# Function to run tests
run_tests() {
    log_info "Running Redfish connectivity tests..."

    cd "${TESTING_DIR}"

    # Check if simulator is running
    if ! curl -s http://localhost:5000/redfish/v1/ &> /dev/null; then
        log_warning "Simulator not running, attempting to start..."
        start_simulator
    fi

    # Run connectivity tests
    if ./test-redfish-connection.sh; then
        log_success "Redfish connectivity tests passed"
    else
        log_error "Redfish connectivity tests failed"
        exit 1
    fi

    # Additional Redfish-specific tests
    log_info "Running additional Redfish validation tests..."
    test_redfish_schema_compliance
}

# Function to test Redfish schema compliance
test_redfish_schema_compliance() {
    local base_url="http://localhost:5000"

    log_info "Testing Redfish schema compliance..."

    # Test required properties in Service Root
    local service_root=$(curl -s "${base_url}/redfish/v1/")

    if echo "${service_root}" | grep -q '"@odata.type".*"#ServiceRoot"'; then
        log_success "Service Root schema compliance: PASS"
    else
        log_warning "Service Root schema compliance: FAIL"
    fi

    # Test Systems collection
    local systems=$(curl -s "${base_url}/redfish/v1/Systems/")
    if echo "${systems}" | grep -q '"@odata.type".*"#ComputerSystemCollection"'; then
        log_success "Systems Collection schema compliance: PASS"
    else
        log_warning "Systems Collection schema compliance: FAIL"
    fi

    # Test System instance
    local system=$(curl -s "${base_url}/redfish/v1/Systems/system/")
    if echo "${system}" | grep -q '"@odata.type".*"#ComputerSystem"'; then
        log_success "System Instance schema compliance: PASS"
    else
        log_warning "System Instance schema compliance: FAIL"
    fi

    # Test BIOS resource
    local bios=$(curl -s "${base_url}/redfish/v1/Systems/system/Bios/")
    if echo "${bios}" | grep -q '"@odata.type".*"#Bios"'; then
        log_success "BIOS Resource schema compliance: PASS"
    else
        log_warning "BIOS Resource schema compliance: FAIL"
    fi
}

# Function to create firmware testing documentation
create_test_documentation() {
    log_info "Creating test documentation..."

    cat > "${TESTING_DIR}/README.md" << 'EOF'
# RPi4 UEFI Redfish Testing

This directory contains tools and scripts for testing the RPi4 UEFI firmware with Redfish support.

## Quick Start

1. **Complete build and test cycle:**
   ```bash
   ./build-and-test.sh --all
   ```

2. **Build firmware only:**
   ```bash
   ./build-and-test.sh --build
   ```

3. **Set up simulator only:**
   ```bash
   ./build-and-test.sh --simulator
   ```

4. **Run tests only:**
   ```bash
   ./build-and-test.sh --test
   ```

## Manual Testing

### Start the Redfish Simulator

```bash
cd redfish-simulator
./start-rpi4-simulator.sh
```

The simulator will be available at `http://localhost:5000`
Default credentials: `root/root123456`

### Test Redfish Endpoints

```bash
# Test service root
curl http://localhost:5000/redfish/v1/

# Test systems collection
curl http://localhost:5000/redfish/v1/Systems/

# Test system instance
curl http://localhost:5000/redfish/v1/Systems/system/

# Test BIOS resource
curl http://localhost:5000/redfish/v1/Systems/system/Bios/
```

### Test Firmware with QEMU (Future Enhancement)

The firmware can be tested with QEMU once network bridge configuration is set up:

```bash
# This is a placeholder for future QEMU testing integration
qemu-system-aarch64 \
  -M virt,secure=on \
  -cpu cortex-a57 \
  -m 1024 \
  -bios ../Build/archive/armstub8-gic.bin \
  -netdev user,id=net0 \
  -device virtio-net-device,netdev=net0
```

## Redfish Client Configuration

The firmware includes the following Redfish client components:

- **RedfishFeatureCoreDxe**: Central feature coordination
- **RedfishConfigLangMapDxe**: Configuration language mapping
- **RedfishETagDxe**: ETag support for caching
- **HiiToRedfishBiosDxe**: BIOS settings synchronization
- **HiiToRedfishBootDxe**: Boot configuration management
- **HiiToRedfishMemoryDxe**: Memory resource management

## Troubleshooting

### Build Issues

1. **Dependencies**: Run `make check-deps` to verify all required tools are installed
2. **Clean build**: Use `./build-and-test.sh --clean --build` for a clean build
3. **Submodules**: Ensure all git submodules are updated: `git submodule update --init --recursive`

### Simulator Issues

1. **Port conflicts**: Ensure port 5000 is available
2. **Python dependencies**: The simulator requires Python 3 and pip packages
3. **Firewall**: Check firewall settings if connecting from remote machines

### Testing Issues

1. **Network connectivity**: Verify the simulator is accessible at `http://localhost:5000`
2. **Credentials**: Default credentials are `root/root123456`
3. **Schema validation**: Check simulator logs for schema compliance issues

## Development Workflow

1. Make changes to Redfish configuration
2. Build firmware: `./build-and-test.sh --build`
3. Test with simulator: `./build-and-test.sh --test`
4. Validate schema compliance
5. Test on actual hardware (when available)
EOF

    log_success "Test documentation created at ${TESTING_DIR}/README.md"
}

# Function to clean build artifacts
clean_build() {
    log_info "Cleaning build artifacts..."

    cd "${PROJECT_ROOT}"
    make clean

    # Stop simulator if running
    stop_simulator

    log_success "Build artifacts cleaned"
}

# Main execution logic
main() {
    local build_firmware=false
    local setup_sim=false
    local run_test=false
    local clean_only=false
    local all_steps=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--build)
                build_firmware=true
                shift
                ;;
            -s|--simulator)
                setup_sim=true
                shift
                ;;
            -t|--test)
                run_test=true
                shift
                ;;
            -c|--clean)
                clean_only=true
                shift
                ;;
            -a|--all)
                all_steps=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # If no arguments provided, show usage
    if [[ $# -eq 0 ]] && [[ "${build_firmware}" == "false" ]] && [[ "${setup_sim}" == "false" ]] && [[ "${run_test}" == "false" ]] && [[ "${clean_only}" == "false" ]] && [[ "${all_steps}" == "false" ]]; then
        show_usage
        exit 1
    fi

    # Handle clean operation
    if [[ "${clean_only}" == "true" ]]; then
        clean_build
        exit 0
    fi

    # Handle all steps
    if [[ "${all_steps}" == "true" ]]; then
        build_firmware=true
        setup_sim=true
        run_test=true
    fi

    # Set up signal handlers for cleanup
    trap 'stop_simulator' EXIT

    # Execute requested operations
    check_prerequisites
    create_test_documentation

    if [[ "${build_firmware}" == "true" ]]; then
        build_firmware
    fi

    if [[ "${setup_sim}" == "true" ]]; then
        setup_simulator
    fi

    if [[ "${run_test}" == "true" ]]; then
        start_simulator
        run_tests
    fi

    log_success "All requested operations completed successfully!"
}

# Run main function with all arguments
main "$@"

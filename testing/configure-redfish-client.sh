#!/bin/bash

# Redfish Client Configuration Script for RPi4
# This script helps configure the UEFI Redfish client to communicate with out-of-band servers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

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

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Configure Redfish client for RPi4 UEFI firmware

Options:
  -t, --type TYPE          Configuration type: 'simulator', 'bmcd', 'static'
  -s, --server IP          Redfish server IP address
  -p, --port PORT          Redfish server port (default: 5000 for simulator, 443 for production)
  -u, --user USER          Username (default: root)
  -w, --password PASS      Password (default: root123456)
  -l, --local IP           Local host IP address (for static configuration)
  -m, --mask MASK          Subnet mask (default: 255.255.255.0)
  -n, --network-interface  Network interface MAC address (optional)
  -c, --create-config      Create configuration files
  -e, --emulator-vars      Generate EFI variable commands for emulator-style setup
  -h, --help               Show this help message

Configuration Types:
  simulator    - Configure for DMTF Redfish Profile Simulator (development)
  bmcd         - Configure for BMC-based discovery (production with BMC)
  static       - Configure for static IP endpoints (testing/lab environments)

Examples:
  # Configure for local simulator testing
  $0 --type simulator --server 127.0.0.1 --port 5000

  # Configure for production BMC environment
  $0 --type bmcd --server 192.168.100.10 --port 443

  # Configure for static IP environment
  $0 --type static --server 10.0.1.100 --local 10.0.1.50 --mask 255.255.255.0

  # Create configuration files and EFI variable commands
  $0 --type simulator --server 192.168.1.100 --create-config --emulator-vars

EOF
}

# Default values
CONFIG_TYPE=""
REDFISH_SERVER=""
REDFISH_PORT=""
REDFISH_USER="root"
REDFISH_PASSWORD="root123456"
LOCAL_IP=""
SUBNET_MASK="255.255.255.0"
NETWORK_MAC=""
CREATE_CONFIG=false
EMULATOR_VARS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            CONFIG_TYPE="$2"
            shift 2
            ;;
        -s|--server)
            REDFISH_SERVER="$2"
            shift 2
            ;;
        -p|--port)
            REDFISH_PORT="$2"
            shift 2
            ;;
        -u|--user)
            REDFISH_USER="$2"
            shift 2
            ;;
        -w|--password)
            REDFISH_PASSWORD="$2"
            shift 2
            ;;
        -l|--local)
            LOCAL_IP="$2"
            shift 2
            ;;
        -m|--mask)
            SUBNET_MASK="$2"
            shift 2
            ;;
        -n|--network-interface)
            NETWORK_MAC="$2"
            shift 2
            ;;
        -c|--create-config)
            CREATE_CONFIG=true
            shift
            ;;
        -e|--emulator-vars)
            EMULATOR_VARS=true
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

# Validate required parameters
if [[ -z "${CONFIG_TYPE}" ]]; then
    log_error "Configuration type is required"
    show_usage
    exit 1
fi

if [[ -z "${REDFISH_SERVER}" ]]; then
    log_error "Redfish server IP is required"
    show_usage
    exit 1
fi

# Set default port based on configuration type
if [[ -z "${REDFISH_PORT}" ]]; then
    case "${CONFIG_TYPE}" in
        simulator)
            REDFISH_PORT="5000"
            ;;
        bmcd|static)
            REDFISH_PORT="443"
            ;;
        *)
            REDFISH_PORT="443"
            ;;
    esac
fi

# Set default local IP for static configuration
if [[ "${CONFIG_TYPE}" == "static" && -z "${LOCAL_IP}" ]]; then
    log_error "Local IP address is required for static configuration"
    exit 1
fi

# Generate auto local IP for simulator if not provided
if [[ "${CONFIG_TYPE}" == "simulator" && -z "${LOCAL_IP}" ]]; then
    # Use a default local IP in the same subnet as the server
    IFS='.' read -ra IP_PARTS <<< "${REDFISH_SERVER}"
    LOCAL_IP="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}.$((${IP_PARTS[3]} - 1))"
    log_info "Auto-generated local IP: ${LOCAL_IP}"
fi

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a ip_parts=($ip)
        for part in "${ip_parts[@]}"; do
            if ((part > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Validate IP addresses
if ! validate_ip "${REDFISH_SERVER}"; then
    log_error "Invalid Redfish server IP: ${REDFISH_SERVER}"
    exit 1
fi

if [[ -n "${LOCAL_IP}" ]] && ! validate_ip "${LOCAL_IP}"; then
    log_error "Invalid local IP: ${LOCAL_IP}"
    exit 1
fi

if ! validate_ip "${SUBNET_MASK}"; then
    log_error "Invalid subnet mask: ${SUBNET_MASK}"
    exit 1
fi

log_info "Configuring Redfish client with the following parameters:"
log_info "  Configuration Type: ${CONFIG_TYPE}"
log_info "  Redfish Server: ${REDFISH_SERVER}:${REDFISH_PORT}"
log_info "  Username: ${REDFISH_USER}"
log_info "  Password: [hidden]"
if [[ -n "${LOCAL_IP}" ]]; then
    log_info "  Local IP: ${LOCAL_IP}"
fi
log_info "  Subnet Mask: ${SUBNET_MASK}"
if [[ -n "${NETWORK_MAC}" ]]; then
    log_info "  Network MAC: ${NETWORK_MAC}"
fi

# Create platform configuration based on type
create_platform_config() {
    local config_file="${PROJECT_ROOT}/platforms/Platform/RaspberryPi/RPi4/RedfishConfig.dsc.inc"

    log_info "Creating platform configuration: ${config_file}"

    cat > "${config_file}" << EOF
# Redfish Configuration Include File
# Generated by configure-redfish-client.sh
# Configuration Type: ${CONFIG_TYPE}

[LibraryClasses]
  # Redfish Platform Libraries
EOF

    case "${CONFIG_TYPE}" in
        simulator)
            cat >> "${config_file}" << EOF
  # Use EmulatorPkg-style configuration for simulator testing
  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceLibNull/PlatformHostInterfaceLibNull.inf
  RedfishPlatformCredentialLib|EmulatorPkg/Library/RedfishPlatformCredentialLib/RedfishPlatformCredentialLib.inf
EOF
            ;;
        bmcd)
            cat >> "${config_file}" << EOF
  # Use BMC-based discovery for production environments
  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib/PlatformHostInterfaceBmcUsbNicLib.inf
  RedfishPlatformCredentialLib|RedfishPkg/Library/RedfishPlatformCredentialLibIpmi/RedfishPlatformCredentialLibIpmi.inf
EOF
            ;;
        static)
            cat >> "${config_file}" << EOF
  # Use static configuration for lab/testing environments
  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceLibNull/PlatformHostInterfaceLibNull.inf
  RedfishPlatformCredentialLib|EmulatorPkg/Library/RedfishPlatformCredentialLib/RedfishPlatformCredentialLib.inf
EOF
            ;;
    esac

    cat >> "${config_file}" << EOF

[PcdsFixedAtBuild]
  # Redfish Service Configuration
  gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServiceUserId|"${REDFISH_USER}"
  gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServicePassword|"${REDFISH_PASSWORD}"

  # Network Configuration
EOF

    if [[ -n "${NETWORK_MAC}" ]]; then
        cat >> "${config_file}" << EOF
  gEfiRedfishPkgTokenSpaceGuid.PcdRedfishRestExServiceDevicePath.DevicePath|{DEVICE_PATH("MAC(${NETWORK_MAC},0x1)")}
EOF
    fi

    case "${CONFIG_TYPE}" in
        simulator)
            cat >> "${config_file}" << EOF

  # HTTP connections allowed for simulator testing
  gEfiNetworkPkgTokenSpaceGuid.PcdAllowHttpConnections|TRUE

  # Content encoding support (simulator typically doesn't support compression)
  gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServiceContentEncoding|"None"
EOF
            ;;
        bmcd|static)
            cat >> "${config_file}" << EOF

  # HTTPS required for production
  gEfiNetworkPkgTokenSpaceGuid.PcdAllowHttpConnections|FALSE

  # Content encoding support
  gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServiceContentEncoding|"gzip"

  # ETAG support for production environments
  gEfiRedfishClientPkgTokenSpaceGuid.PcdRedfishServiceEtagSupported|TRUE
EOF
            ;;
    esac

    log_success "Platform configuration created: ${config_file}"
}

# Create EFI variable commands for manual configuration
create_efi_variable_commands() {
    local var_file="${PROJECT_ROOT}/testing/redfish-efi-variables.txt"

    log_info "Creating EFI variable commands: ${var_file}"

    cat > "${var_file}" << EOF
# EFI Variable Commands for Redfish Configuration
# Generated by configure-redfish-client.sh
# Configuration Type: ${CONFIG_TYPE}
#
# Use these commands in the EFI Shell to configure Redfish service settings

# Method 1: Using RedfishPlatformConfig.efi application
EOF

    case "${CONFIG_TYPE}" in
        simulator|static)
            if [[ -n "${LOCAL_IP}" ]]; then
                cat >> "${var_file}" << EOF
RedfishPlatformConfig.efi -s ${LOCAL_IP} ${SUBNET_MASK} ${REDFISH_SERVER} ${SUBNET_MASK} ${REDFISH_PORT}
EOF
            else
                cat >> "${var_file}" << EOF
RedfishPlatformConfig.efi -a ${REDFISH_SERVER} ${SUBNET_MASK} ${REDFISH_PORT}
EOF
            fi
            ;;
        bmcd)
            cat >> "${var_file}" << EOF
# For BMC-based configuration, service discovery is automatic
# No manual configuration required - settings discovered via IPMI
EOF
            ;;
    esac

    cat >> "${var_file}" << EOF

# Method 2: Manual variable setting (if RedfishPlatformConfig.efi is not available)
# Note: These are raw setvar commands - USE WITH CAUTION

# Service endpoint configuration
setvar HostIpAssignmentType -guid 84A67BD6-AC91-4F3C-AA5A-A89D82FD4E96 -bs -nv =01
EOF

    if [[ -n "${LOCAL_IP}" ]]; then
        # Convert IP to hex bytes
        IFS='.' read -ra IP_PARTS <<< "${LOCAL_IP}"
        LOCAL_IP_HEX=$(printf "%02x %02x %02x %02x" "${IP_PARTS[0]}" "${IP_PARTS[1]}" "${IP_PARTS[2]}" "${IP_PARTS[3]}")

        IFS='.' read -ra MASK_PARTS <<< "${SUBNET_MASK}"
        MASK_HEX=$(printf "%02x %02x %02x %02x" "${MASK_PARTS[0]}" "${MASK_PARTS[1]}" "${MASK_PARTS[2]}" "${MASK_PARTS[3]}")

        cat >> "${var_file}" << EOF
setvar HostIpAddress -guid 84A67BD6-AC91-4F3C-AA5A-A89D82FD4E96 -bs -nv =${LOCAL_IP_HEX}
setvar HostIpMask -guid 84A67BD6-AC91-4F3C-AA5A-A89D82FD4E96 -bs -nv =${MASK_HEX}
EOF
    fi

    # Convert server IP to hex bytes
    IFS='.' read -ra SERVER_PARTS <<< "${REDFISH_SERVER}"
    SERVER_IP_HEX=$(printf "%02x %02x %02x %02x" "${SERVER_PARTS[0]}" "${SERVER_PARTS[1]}" "${SERVER_PARTS[2]}" "${SERVER_PARTS[3]}")

    IFS='.' read -ra MASK_PARTS <<< "${SUBNET_MASK}"
    MASK_HEX=$(printf "%02x %02x %02x %02x" "${MASK_PARTS[0]}" "${MASK_PARTS[1]}" "${MASK_PARTS[2]}" "${MASK_PARTS[3]}")

    # Convert port to hex (little-endian 16-bit)
    PORT_HEX=$(printf "%02x %02x" $((REDFISH_PORT & 0xFF)) $((REDFISH_PORT >> 8)))

    cat >> "${var_file}" << EOF
setvar RedfishServiceIpAddress -guid 84A67BD6-AC91-4F3C-AA5A-A89D82FD4E96 -bs -nv =${SERVER_IP_HEX}
setvar RedfishServiceIpMask -guid 84A67BD6-AC91-4F3C-AA5A-A89D82FD4E96 -bs -nv =${MASK_HEX}
setvar RedfishServiceIpPort -guid 84A67BD6-AC91-4F3C-AA5A-A89D82FD4E96 -bs -nv =${PORT_HEX}

# Restart the system after setting variables for changes to take effect
reset
EOF

    log_success "EFI variable commands created: ${var_file}"
}

# Create test configuration files
create_test_config() {
    local test_config="${PROJECT_ROOT}/testing/redfish-test-config.json"

    log_info "Creating test configuration: ${test_config}"

    cat > "${test_config}" << EOF
{
  "configuration_type": "${CONFIG_TYPE}",
  "redfish_service": {
    "ip_address": "${REDFISH_SERVER}",
    "port": ${REDFISH_PORT},
    "username": "${REDFISH_USER}",
    "password": "${REDFISH_PASSWORD}",
    "base_url": "http://${REDFISH_SERVER}:${REDFISH_PORT}"
  },
  "network_config": {
    "local_ip": "${LOCAL_IP}",
    "subnet_mask": "${SUBNET_MASK}",
    "network_mac": "${NETWORK_MAC}"
  },
  "test_endpoints": [
    "/redfish/v1/",
    "/redfish/v1/Systems/",
    "/redfish/v1/Systems/system/",
    "/redfish/v1/Systems/system/Bios/",
    "/redfish/v1/Chassis/",
    "/redfish/v1/Managers/"
  ],
  "expected_resources": {
    "service_root": {
      "required_properties": ["@odata.type", "@odata.id", "Name", "RedfishVersion"]
    },
    "computer_system": {
      "required_properties": ["@odata.type", "@odata.id", "Name", "SystemType", "Boot"]
    },
    "bios": {
      "required_properties": ["@odata.type", "@odata.id", "Name", "Attributes"]
    }
  }
}
EOF

    log_success "Test configuration created: ${test_config}"
}

# Create a simple validation script
create_validation_script() {
    local validation_script="${PROJECT_ROOT}/testing/validate-redfish-config.sh"

    log_info "Creating validation script: ${validation_script}"

    cat > "${validation_script}" << 'EOF'
#!/bin/bash

# Validate Redfish configuration
# This script tests the configured Redfish endpoints

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/redfish-test-config.json"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Configuration file not found: ${CONFIG_FILE}"
    echo "Please run configure-redfish-client.sh first"
    exit 1
fi

# Extract configuration using jq (if available) or basic parsing
if command -v jq &> /dev/null; then
    BASE_URL=$(jq -r '.redfish_service.base_url' "${CONFIG_FILE}")
    USERNAME=$(jq -r '.redfish_service.username' "${CONFIG_FILE}")
    PASSWORD=$(jq -r '.redfish_service.password' "${CONFIG_FILE}")
else
    # Basic parsing without jq
    BASE_URL=$(grep '"base_url"' "${CONFIG_FILE}" | sed 's/.*"base_url": "\([^"]*\)".*/\1/')
    USERNAME=$(grep '"username"' "${CONFIG_FILE}" | sed 's/.*"username": "\([^"]*\)".*/\1/')
    PASSWORD=$(grep '"password"' "${CONFIG_FILE}" | sed 's/.*"password": "\([^"]*\)".*/\1/')
fi

echo "Validating Redfish configuration..."
echo "Base URL: ${BASE_URL}"
echo "Username: ${USERNAME}"
echo ""

# Test endpoints
ENDPOINTS=(
    "/redfish/v1/"
    "/redfish/v1/Systems/"
    "/redfish/v1/Systems/system/"
    "/redfish/v1/Systems/system/Bios/"
)

for endpoint in "${ENDPOINTS[@]}"; do
    echo -n "Testing ${endpoint}... "
    if curl -s -f -u "${USERNAME}:${PASSWORD}" "${BASE_URL}${endpoint}" > /dev/null; then
        echo "OK"
    else
        echo "FAILED"
        exit 1
    fi
done

echo ""
echo "All endpoints validated successfully!"
echo "Redfish service is properly configured and accessible."
EOF

    chmod +x "${validation_script}"
    log_success "Validation script created: ${validation_script}"
}

# Main execution
main() {
    log_info "Starting Redfish client configuration..."

    if [[ "${CREATE_CONFIG}" == "true" ]]; then
        create_platform_config
        create_test_config
        create_validation_script
    fi

    if [[ "${EMULATOR_VARS}" == "true" ]]; then
        create_efi_variable_commands
    fi

    # Display configuration summary
    log_success "Redfish client configuration completed!"
    echo ""
    log_info "Configuration Summary:"
    log_info "  Type: ${CONFIG_TYPE}"
    log_info "  Server: ${REDFISH_SERVER}:${REDFISH_PORT}"
    if [[ -n "${LOCAL_IP}" ]]; then
        log_info "  Local IP: ${LOCAL_IP}"
    fi
    log_info "  Authentication: ${REDFISH_USER}/[password hidden]"

    echo ""
    log_info "Next Steps:"

    case "${CONFIG_TYPE}" in
        simulator)
            log_info "1. Start the Redfish simulator:"
            log_info "   cd testing && ./setup-redfish-simulator.sh"
            log_info "   cd redfish-simulator && ./start-rpi4-simulator.sh"
            log_info ""
            log_info "2. Boot the RPi4 UEFI firmware and configure via EFI Shell:"
            if [[ "${EMULATOR_VARS}" == "true" ]]; then
                log_info "   Use commands from: testing/redfish-efi-variables.txt"
            else
                if [[ -n "${LOCAL_IP}" ]]; then
                    log_info "   RedfishPlatformConfig.efi -s ${LOCAL_IP} ${SUBNET_MASK} ${REDFISH_SERVER} ${SUBNET_MASK} ${REDFISH_PORT}"
                else
                    log_info "   RedfishPlatformConfig.efi -a ${REDFISH_SERVER} ${SUBNET_MASK} ${REDFISH_PORT}"
                fi
            fi
            ;;
        bmcd)
            log_info "1. Ensure BMC is properly configured with USB NIC exposure"
            log_info "2. Verify IPMI channel configuration for Redfish bootstrapping"
            log_info "3. Boot the RPi4 UEFI firmware - service discovery should be automatic"
            ;;
        static)
            log_info "1. Configure your Redfish service at ${REDFISH_SERVER}:${REDFISH_PORT}"
            log_info "2. Boot the RPi4 UEFI firmware and configure via EFI Shell:"
            if [[ "${EMULATOR_VARS}" == "true" ]]; then
                log_info "   Use commands from: testing/redfish-efi-variables.txt"
            else
                log_info "   RedfishPlatformConfig.efi -s ${LOCAL_IP} ${SUBNET_MASK} ${REDFISH_SERVER} ${SUBNET_MASK} ${REDFISH_PORT}"
            fi
            ;;
    esac

    echo ""
    log_info "3. Test the configuration:"
    if [[ "${CREATE_CONFIG}" == "true" ]]; then
        log_info "   ./testing/validate-redfish-config.sh"
    else
        log_info "   curl -u ${REDFISH_USER}:${REDFISH_PASSWORD} ${REDFISH_SERVER}:${REDFISH_PORT}/redfish/v1/"
    fi

    echo ""
    log_info "For more information, see: docs/RedfishClientConfiguration.md"
}

# Execute main function
main

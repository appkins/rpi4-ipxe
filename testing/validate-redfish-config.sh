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
    "/redfish/v1/Systems/2M220100SL/"
)

# Optional endpoints (may not exist in all simulators)
OPTIONAL_ENDPOINTS=(
    "/redfish/v1/Systems/2M220100SL/Bios/"
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

# Test optional endpoints
for endpoint in "${OPTIONAL_ENDPOINTS[@]}"; do
    echo -n "Testing ${endpoint} (optional)... "
    if curl -s -f -u "${USERNAME}:${PASSWORD}" "${BASE_URL}${endpoint}" > /dev/null; then
        echo "OK"
    else
        echo "SKIPPED (not available)"
    fi
done

echo ""
echo "All endpoints validated successfully!"
echo "Redfish service is properly configured and accessible."

#!/bin/bash

# Test script to verify Redfish simulator connectivity
# Usage: ./test-redfish-connection.sh [host] [port]

HOST="${1:-localhost}"
PORT="${2:-5000}"
BASE_URL="http://${HOST}:${PORT}"

echo "Testing Redfish simulator connection..."
echo "Base URL: ${BASE_URL}"
echo ""

# Test service root
echo "1. Testing Service Root..."
if curl -s -f "${BASE_URL}/redfish/v1/" > /dev/null; then
    echo "✓ Service Root accessible"
    curl -s "${BASE_URL}/redfish/v1/" | python3 -m json.tool | head -20
else
    echo "✗ Service Root not accessible"
    exit 1
fi

echo ""

# Test systems collection
echo "2. Testing Systems Collection..."
if curl -s -f "${BASE_URL}/redfish/v1/Systems/" > /dev/null; then
    echo "✓ Systems Collection accessible"
    curl -s "${BASE_URL}/redfish/v1/Systems/" | python3 -m json.tool
else
    echo "✗ Systems Collection not accessible"
fi

echo ""

# Test system instance
echo "3. Testing System Instance..."
if curl -s -f "${BASE_URL}/redfish/v1/Systems/system/" > /dev/null; then
    echo "✓ System Instance accessible"
    curl -s "${BASE_URL}/redfish/v1/Systems/system/" | python3 -m json.tool | head -30
else
    echo "✗ System Instance not accessible"
fi

echo ""

# Test BIOS resource
echo "4. Testing BIOS Resource..."
if curl -s -f "${BASE_URL}/redfish/v1/Systems/system/Bios/" > /dev/null; then
    echo "✓ BIOS Resource accessible"
    curl -s "${BASE_URL}/redfish/v1/Systems/system/Bios/" | python3 -m json.tool | head -20
else
    echo "✗ BIOS Resource not accessible"
fi

echo ""
echo "Redfish simulator connection test completed!"

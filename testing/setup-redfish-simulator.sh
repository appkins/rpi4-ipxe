#!/bin/bash

# Setup script for DMTF Redfish Profile Simulator
# This script downloads and sets up the Redfish simulator for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIMULATOR_DIR="${SCRIPT_DIR}/redfish-simulator"
SIMULATOR_REPO="https://github.com/DMTF/Redfish-Profile-Simulator.git"
SIMULATOR_BRANCH="main"

echo "Setting up DMTF Redfish Profile Simulator..."

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed"
    echo "Install Python 3 and try again"
    exit 1
fi

# Check for pip3
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is required but not installed"
    echo "Install pip3 and try again"
    exit 1
fi

# Clone or update the simulator repository
if [ -d "${SIMULATOR_DIR}/.git" ]; then
    echo "Updating existing Redfish Profile Simulator..."
    cd "${SIMULATOR_DIR}"
    git fetch origin
    git reset --hard origin/${SIMULATOR_BRANCH}
else
    echo "Cloning Redfish Profile Simulator..."
    rm -rf "${SIMULATOR_DIR}"
    git clone "${SIMULATOR_REPO}" "${SIMULATOR_DIR}"
    cd "${SIMULATOR_DIR}"
    git checkout "${SIMULATOR_BRANCH}"
fi

# Create and activate virtual environment
echo "Setting up Python virtual environment..."
VENV_DIR="${SIMULATOR_DIR}/venv"

if [ ! -d "${VENV_DIR}" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi

echo "Activating virtual environment..."
source "${VENV_DIR}/bin/activate"

# Upgrade pip in the virtual environment
echo "Upgrading pip..."
pip install --upgrade pip

# Install Python dependencies in virtual environment
echo "Installing Python dependencies in virtual environment..."
pip install Flask

# Create a configuration for RPi4 testing
echo "Creating RPi4 test configuration..."
cat > "${SIMULATOR_DIR}/rpi4-config.json" << 'EOF'
{
    "ServiceRoot": {
        "Id": "RootService",
        "Name": "Root Service",
        "RedfishVersion": "1.15.1",
        "UUID": "92384634-2938-2342-8820-489239905423"
    },
    "Systems": [
        {
            "Id": "system",
            "Name": "Raspberry Pi 4",
            "SystemType": "Physical",
            "Manufacturer": "Raspberry Pi Foundation",
            "Model": "Raspberry Pi 4 Model B",
            "SerialNumber": "RPI4-EDK2-TEST-001",
            "PartNumber": "RPI4B",
            "UUID": "38947555-7742-3448-3784-823347823834",
            "ProcessorSummary": {
                "Count": 4,
                "Model": "ARM Cortex-A72"
            },
            "MemorySummary": {
                "TotalSystemMemoryGiB": 4
            },
            "Boot": {
                "BootSourceOverrideEnabled": "Once",
                "BootSourceOverrideMode": "UEFI",
                "BootSourceOverrideTarget": "Hdd",
                "BootOrder": ["Boot0001", "Boot0002", "Boot0003"]
            },
            "Bios": {
                "@odata.id": "/redfish/v1/Systems/system/Bios"
            }
        }
    ],
    "Chassis": [
        {
            "Id": "chassis",
            "Name": "Raspberry Pi 4 Chassis",
            "ChassisType": "RackMount",
            "Manufacturer": "Raspberry Pi Foundation",
            "Model": "Raspberry Pi 4 Case",
            "SerialNumber": "RPI4-CHASSIS-001"
        }
    ],
    "Managers": [
        {
            "Id": "bmc",
            "Name": "Raspberry Pi 4 BMC Simulator",
            "ManagerType": "BMC",
            "Model": "Simulated BMC",
            "FirmwareVersion": "1.0.0"
        }
    ]
}
EOF

# Create startup script
cat > "${SIMULATOR_DIR}/start-rpi4-simulator.sh" << 'EOF'
#!/bin/bash

# Start the Redfish Profile Simulator configured for RPi4 testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"

echo "Starting Redfish Profile Simulator for RPi4 testing..."
echo "Simulator will be available at: http://localhost:5000"
echo "Default credentials: root/root123456"
echo ""
echo "Press Ctrl+C to stop the simulator"
echo ""

# Activate virtual environment
if [ -f "${VENV_DIR}/bin/activate" ]; then
    source "${VENV_DIR}/bin/activate"
else
    echo "Error: Virtual environment not found at ${VENV_DIR}"
    echo "Please run setup-redfish-simulator.sh first"
    exit 1
fi

cd "${SCRIPT_DIR}"
python redfishProfileSimulator.py --config rpi4-config.json --host 0.0.0.0 --port 5000
EOF

chmod +x "${SIMULATOR_DIR}/start-rpi4-simulator.sh"

# Create test script
cat > "${SCRIPT_DIR}/test-redfish-connection.sh" << 'EOF'
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
EOF

chmod +x "${SCRIPT_DIR}/test-redfish-connection.sh"

echo ""
echo "✓ Redfish Profile Simulator setup completed!"
echo ""
echo "To start the simulator:"
echo "  cd ${SIMULATOR_DIR}"
echo "  ./start-rpi4-simulator.sh"
echo ""
echo "To test the connection:"
echo "  ${SCRIPT_DIR}/test-redfish-connection.sh"
echo ""
echo "The simulator will be available at: http://localhost:5000"
echo "Default credentials: root/root123456"

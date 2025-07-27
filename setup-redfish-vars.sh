#!/bin/bash

# Setup Redfish Service EFI Variables
# This script sets up the EFI variables needed for the Redfish service discovery fallback

echo "Setting up Redfish Service EFI variables..."

# Check if we're in a UEFI environment (this is for testing purposes)
# In a real UEFI environment, these would be set through the firmware setup or runtime

# Default Redfish simulator configuration
REDFISH_IP="127.0.0.1"
REDFISH_PORT=5000

# Create a template for setting these variables in UEFI environment
cat > redfish-config-template.nsh << 'EOF'
# UEFI Shell script to set Redfish service variables
# This should be run in the UEFI shell environment

# Set Redfish Service IP Address
setvar RedfishServiceIpAddress -guid 8399a787-108e-4e53-9ede-4b18cc9eab3b -bs -rt =L"127.0.0.1"

# Set Redfish Service Port (optional, defaults to 5000)
setvar RedfishServiceIpPort -guid 8399a787-108e-4e53-9ede-4b18cc9eab3b -bs -rt =0x1388

echo "Redfish service variables set for 127.0.0.1:5000"
EOF

echo "Created redfish-config-template.nsh for UEFI shell"
echo ""
echo "To set up the Redfish service in UEFI:"
echo "1. Copy redfish-config-template.nsh to your UEFI shell environment"
echo "2. Run the script in UEFI shell: redfish-config-template.nsh"
echo ""
echo "Or modify the IP address and port in the template as needed."
echo ""
echo "The variables will be:"
echo "  RedfishServiceIpAddress = \"${REDFISH_IP}\""
echo "  RedfishServiceIpPort = ${REDFISH_PORT}"

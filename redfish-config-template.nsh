# UEFI Shell script to set Redfish service variables
# This should be run in the UEFI shell environment

# Set Redfish Service IP Address
setvar RedfishServiceIpAddress -guid 8399a787-108e-4e53-9ede-4b18cc9eab3b -bs -rt =L"127.0.0.1"

# Set Redfish Service Port (optional, defaults to 5000)
setvar RedfishServiceIpPort -guid 8399a787-108e-4e53-9ede-4b18cc9eab3b -bs -rt =0x1388

echo "Redfish service variables set for 127.0.0.1:5000"

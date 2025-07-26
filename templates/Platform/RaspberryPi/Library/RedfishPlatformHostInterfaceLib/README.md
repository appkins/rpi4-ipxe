# Raspberry Pi Redfish Platform Host Interface Library

## Overview

This library provides out-of-band Redfish Host Interface support for Raspberry Pi platforms using the onboard Ethernet controller. It replaces USB-based implementations with PCI-based device discovery and configuration.

## Key Features

- **Out-of-band access**: No BMC or IPMI dependencies
- **PCI-based**: Uses `EFI_PCI_IO_PROTOCOL` instead of `EFI_USB_IO_PROTOCOL`
- **Platform-specific**: Tailored for Raspberry Pi onboard network interfaces
- **Standards-compliant**: Uses `PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2` from DMTF specs

## Implementation Details

### Device Discovery

The library identifies Raspberry Pi onboard network interfaces by:

1. Scanning for Simple Network Protocol (SNP) instances
2. Finding associated PCI IO protocols
3. Checking for known Raspberry Pi network controller vendor IDs:
   - **Broadcom (0x14E4)**: Common on Raspberry Pi 4 and newer
   - **Microchip (0x0424)**: Used for USB-to-Ethernet bridges on some models

### Configuration

The implementation uses static IP configuration for Redfish services:

- **Host IP**: 192.168.1.100/24
- **Redfish Service IP**: 192.168.1.10/24
- **Gateway**: 192.168.1.1
- **No VLAN**: VlanId = 0

> **Note**: In production deployments, these should be configurable via platform-specific PCDs or UEFI variables.

### Protocol Support

- **Device Type**: `REDFISH_HOST_INTERFACE_DEVICE_TYPE_PCI_PCIE_V2` (0x05)
- **Protocol**: Redfish over IP
- **IP Version**: IPv4 only (for now)
- **Authentication**: Supports credential bootstrapping

## Integration

To use this library in your platform:

1. Add the library to your platform's `.dsc` file:

   ```ini
   RedfishPlatformHostInterfaceLib|templates/Platform/RaspberryPi/Library/RedfishPlatformHostInterfaceLib/RedfishPlatformHostInterfaceLib.inf
   ```

2. Ensure required PCDs are set:

   ```ini
   gEfiRedfishPkgTokenSpaceGuid.PcdRedfishHostName|"rpi-redfish"
   gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServiceUuid|"00000000-0000-0000-0000-000000000000"
   gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServicePort|443
   ```

3. Include required protocols and dependencies in your platform build.

## Differences from USB Implementation

| Aspect | USB Implementation | PCI Implementation |
|--------|-------------------|-------------------|
| **Protocol** | `EFI_USB_IO_PROTOCOL` | `EFI_PCI_IO_PROTOCOL` |
| **Device Type** | `REDFISH_HOST_INTERFACE_DEVICE_TYPE_USB_V2` | `REDFISH_HOST_INTERFACE_DEVICE_TYPE_PCI_PCIE_V2` |
| **Descriptor** | `USB_INTERFACE_DEVICE_DESCRIPTOR_V2` | `PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2` |
| **Discovery** | USB device enumeration + IPMI | PCI device enumeration only |
| **Configuration** | IPMI LAN configuration | Static/platform-specific |

## Future Enhancements

- [ ] Dynamic IP configuration support
- [ ] IPv6 support
- [ ] Multiple network interface support
- [ ] Platform-specific PCD configuration
- [ ] Advanced device path matching
- [ ] Integration with platform firmware variables

## Testing

This implementation can be tested by:

1. Building the UEFI firmware with this library included
2. Booting on a Raspberry Pi with network connectivity
3. Verifying SMBIOS Type 42 record creation
4. Testing Redfish service connectivity

## Standards Compliance

This implementation follows:

- **DMTF Redfish Host Interface Specification v1.3**
- **SMBIOS 3.x Type 42 (Management Controller Host Interface)**
- **UEFI Specification 2.x**

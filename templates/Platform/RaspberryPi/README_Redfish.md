# Raspberry Pi Redfish Integration

## Overview

This implementation adds Redfish Host Interface support to the Raspberry Pi platform with the following components:

### Components

1. **RedfishPlatformHostInterfaceLib** (`templates/Platform/RaspberryPi/Library/RedfishPlatformHostInterfaceLib/`)
   - Provides out-of-band Redfish Host Interface support
   - Uses PCI-based device discovery instead of USB
   - Implements `PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2`
   - No BMC or IPMI dependencies

2. **RedfishPlatformCredentialLib** (`templates/Platform/RaspberryPi/Library/RedfishPlatformCredentialLib/`)
   - Manages Redfish authentication credentials
   - Supports both no-authentication and HTTP Basic authentication
   - Uses EFI variables with PCD fallbacks
   - No secure boot restrictions (unlike standard implementations)

3. **ConfigDxe Driver** (`templates/Platform/RaspberryPi/Drivers/ConfigDxe/`)
   - Extended to include Redfish service configuration form
   - Provides UI for authentication settings
   - Manages credential variables

### Configuration Variables

The following EFI variables are used for Redfish configuration:

| Variable Name | Type | Description |
|---------------|------|-------------|
| `RedfishServiceAuthenticationEnabled` | BOOLEAN | Enable/disable authentication |
| `RedfishServiceUserId` | STRING | Username for HTTP Basic auth |
| `RedfishServicePassword` | STRING | Password for HTTP Basic auth |

All variables use the GUID: `FB833014-7A04-42F6-881A-374D9DB6293A`

### Authentication Modes

#### No Authentication (`AuthMethodNone`)

- Set `RedfishServiceAuthenticationEnabled` = FALSE
- No credentials required
- Suitable for secure lab environments

#### HTTP Basic Authentication (`AuthMethodHttpBasic`)

- Set `RedfishServiceAuthenticationEnabled` = TRUE
- Requires valid `RedfishServiceUserId` and `RedfishServicePassword`
- Standard HTTP Basic authentication

### Platform Integration

To integrate these libraries into your Raspberry Pi platform:

1. **Add Library Implementations:**

   ```ini
   [LibraryClasses.common]
     RedfishPlatformHostInterfaceLib|templates/Platform/RaspberryPi/Library/RedfishPlatformHostInterfaceLib/RedfishPlatformHostInterfaceLib.inf
     RedfishPlatformCredentialLib|templates/Platform/RaspberryPi/Library/RedfishPlatformCredentialLib/RedfishPlatformCredentialLib.inf
   ```

2. **Include ConfigDxe Driver:**

   ```ini
   [Components.common]
     templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxe.inf
   ```

3. **Add Required Packages:**

   ```ini
   [Packages]
     RedfishPkg/RedfishPkg.dec
   ```

### Default Configuration

If no EFI variables are set, the system defaults to:

- Authentication: Disabled (`AuthMethodNone`)
- User ID: "admin" (if authentication enabled via other means)
- Password: "password" (if authentication enabled via other means)

### Network Configuration

The Host Interface uses static IP configuration:

- Host IP: 192.168.1.100/24
- Redfish Service IP: 192.168.1.10/24
- Gateway: 192.168.1.1
- Port: 443 (HTTPS)

> **Note:** In production, these should be made configurable via PCDs or additional EFI variables.

### Device Detection

The library identifies Raspberry Pi network interfaces by checking for:

- Broadcom vendor ID (0x14E4) - Common on RPi 4+
- Microchip vendor ID (0x0424) - USB-to-Ethernet bridges

### Differences from Standard EDK2 Implementation

1. **No Secure Boot Restrictions:** Unlike standard RedfishPkg implementations, this does not halt on disabled secure boot
2. **PCI Instead of USB:** Uses PCI device enumeration instead of USB device discovery
3. **Static Configuration:** Uses fixed IP addresses instead of IPMI configuration
4. **No BMC Dependencies:** Completely standalone implementation

### Security Considerations

- **Development Use:** This implementation is designed for development and lab environments
- **No Secure Boot:** The credential library does not enforce secure boot
- **Static Credentials:** Default credentials should be changed in production
- **Network Security:** Ensure proper network isolation for Redfish traffic

### Future Enhancements

- [ ] Dynamic IP configuration support
- [ ] IPv6 support  
- [ ] Configurable network parameters via EFI variables
- [ ] Integration with platform firmware variables
- [ ] Support for additional authentication methods

# Redfish External Service Configuration

This documentation describes the modifications made to enable external Redfish service configuration through the UEFI setup interface for the Raspberry Pi 4 platform.

## Overview

The configuration has been simplified to focus exclusively on external Redfish service connectivity, removing the local service options and implementing a proper PCD-based configuration system.

## Architecture Changes

### 1. Platform Configuration Database (PCD) Updates

The following PCDs have been added to `templates/Platform/RaspberryPi/RaspberryPi.dec`:

```c
[PcdsFixedAtBuild]
  # External Redfish Service Configuration
  gRaspberryPiTokenSpaceGuid.PcdRedfishServiceHost|""|VOID*|0x0000002C
  gRaspberryPiTokenSpaceGuid.PcdRedfishServicePort|443|UINT16|0x0000002D
  gRaspberryPiTokenSpaceGuid.PcdRedfishServiceUseHttps|TRUE|BOOLEAN|0x0000002E
  gRaspberryPiTokenSpaceGuid.PcdRedfishServiceSkipCertVerification|FALSE|BOOLEAN|0x0000002F
```

These PCDs provide default values that can be overridden through the UEFI variables.

### 2. Configuration Variables Structure

The configuration uses simplified data structures defined in `ConfigVars.h`:

- **REDFISH_HOSTNAME_VARSTORE_DATA**: Stores the external Redfish service hostname/IP
- **REDFISH_PORT_VARSTORE_DATA**: Stores the service port number
- **REDFISH_USE_HTTPS_VARSTORE_DATA**: Boolean flag for HTTPS usage
- **REDFISH_SKIP_CERT_VARSTORE_DATA**: Boolean flag for certificate verification

### 3. UEFI Setup Interface

The setup interface provides a single "External Redfish Service" section with the following configurable options:

- **Hostname/IP Address**: Text input for the Redfish service endpoint
- **Port**: Numeric input for the service port (default: 443 for HTTPS, 80 for HTTP)
- **Use HTTPS**: Boolean toggle for secure communication
- **Skip Certificate Verification**: Boolean toggle for testing with self-signed certificates

### 4. Host Interface Implementation

The `RedfishPlatformHostInterfaceLib` has been completely rewritten to:

1. Read configuration from UEFI variables first, with PCD fallbacks
2. Construct proper REDFISH_OVER_IP_PROTOCOL_DATA structures
3. Support external service discovery through hostname resolution
4. Integrate with the EDK2 Redfish client stack

## File Modifications

### Core Configuration Files

1. **templates/Platform/RaspberryPi/RaspberryPi.dec**
   - Added external service PCDs
   - Added service GUID definition

2. **templates/Platform/RaspberryPi/RPi4/RPi4.dsc**
   - Updated PCD references
   - Maintained REDFISH_ENABLE build flag

3. **templates/Platform/RaspberryPi/Include/ConfigVars.h**
   - Simplified variable structures
   - Removed local service variables
   - Added external service configuration

### ConfigDxe Driver Updates

4. **templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxeHii.vfr**
   - Simplified form to external service only
   - Added proper variable bindings
   - Removed local service controls

5. **templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxeHii.uni**
   - Updated string resources
   - Removed local service strings
   - Added x-UEFI-redfish language definition

6. **templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxe.c**
   - Updated variable initialization
   - Added PCD-based default values
   - Simplified to external service only

7. **templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxe.inf**
   - Updated PCD references
   - Added required library dependencies

### Library Implementation

8. **templates/Platform/RaspberryPi/Library/RedfishPlatformHostInterfaceLib/RedfishPlatformHostInterfaceLib.c**
   - Complete rewrite for external service support
   - Variable-based configuration reading
   - Proper protocol data construction
   - PCD fallback support

9. **templates/Platform/RaspberryPi/Library/RedfishPlatformHostInterfaceLib/RedfishPlatformHostInterfaceLib.inf**
   - Updated dependencies
   - Added PCD and GUID references

### Header Files

10. **templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxe.h**
    - Copied from platforms directory

11. **templates/Platform/RaspberryPi/Drivers/ConfigDxe/ConfigDxeFormSetGuid.h**
    - Copied from platforms directory
    - Provides GUID for variable storage

## Configuration Flow

1. **Build Time**: PCDs provide default values
2. **Boot Time**: ConfigDxe initializes variables with PCD defaults (if not already set)
3. **Setup Time**: User can modify values through UEFI setup interface
4. **Runtime**: RedfishPlatformHostInterfaceLib reads variables and constructs protocol data
5. **Service Discovery**: EDK2 Redfish client uses the protocol data to connect to external service

## Integration with Redfish Client

The configuration integrates with the existing `redfish-client` submodule by:

- Following EDK2 Redfish client patterns for host interface discovery
- Using standard REDFISH_OVER_IP_PROTOCOL_DATA structures
- Supporting authentication through the existing credential libraries
- Maintaining compatibility with the Redfish feature driver startup sequence

## Authentication

User credentials are managed through existing PCDs:

- `gRaspberryPiTokenSpaceGuid.PcdRedfishServiceUserId`
- `gRaspberryPiTokenSpaceGuid.PcdRedfishServicePassword`

These can be set at build time or managed through the credential library.

## Testing Considerations

When `PcdRedfishServiceSkipCertVerification` is enabled, the system will accept self-signed certificates. This should only be used in testing environments.

## Build Integration

The template overlay system ensures that these modifications are applied during the build process without modifying the upstream submodules directly. Use `make apply-templates` to apply the changes before building.

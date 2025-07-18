# Redfish Profile Simulator Setup

## Overview

The Redfish Profile Simulator provides a local Redfish service that can be used to test and develop Redfish client functionality. This simulator implements the DMTF Redfish specification and provides a complete server mockup for testing RPi4 UEFI Redfish integration.

## Prerequisites

- Python 3.x
- pip (Python package manager)

## Installation and Setup

### 1. Install Python Dependencies

The simulator requires several Python packages. Install them using:

```bash
cd redfish-client/Tools/Redfish-Profile-Simulator
pip3 install -r requirements.txt
```

Or if you prefer using the Makefile target:

```bash
make setup-simulator
```

### 2. Available Makefile Targets

| Target | Description |
|--------|-------------|
| `setup-simulator` | Install Python dependencies for the simulator |
| `start-simulator` | Start the Redfish simulator on localhost:5000 |
| `stop-simulator` | Stop the running simulator |
| `simulator-status` | Check if the simulator is running |

### 3. Running the Simulator

Start the simulator with:

```bash
make start-simulator
```

The simulator will be available at: `http://localhost:5000/redfish/v1/`

Default credentials:

- Username: `root`
- Password: `password123456`

### 4. Testing the Simulator

You can test the simulator using curl:

```bash
# Get service root
curl -u root:password123456 http://localhost:5000/redfish/v1/

# Get system information
curl -u root:password123456 http://localhost:5000/redfish/v1/Systems/1/

# Get BIOS settings
curl -u root:password123456 http://localhost:5000/redfish/v1/Systems/1/Bios/
```

## RPi4 UEFI Integration

### Configuration

The RPi4 UEFI firmware is pre-configured to connect to the simulator with the following settings:

- **Service URL**: Automatically discovered via network detection
- **Username**: `root` (configurable via EFI variables)
- **Password**: `password123456` (configurable via EFI variables)
- **Protocol**: HTTP (for simulator compatibility)

### Using RedfishPlatformConfig.efi

The firmware includes a configuration application that can be run from the EFI Shell:

```
# Configure service manually
RedfishPlatformConfig.efi -s

# Configure service automatically (auto-discovery)
RedfishPlatformConfig.efi -a
```

### EFI Variable Configuration

The Redfish client can also be configured using EFI variables:

1. **RedfishServiceIpAddress**: IP address of the Redfish service
2. **RedfishServiceIpPort**: Port number (default: 5000)
3. **RedfishServiceUserId**: Username for authentication
4. **RedfishServicePassword**: Password for authentication

These variables use the GUID: `gEmuRedfishServiceGuid`

## Network Requirements

### Simulator Network Access

The simulator runs on the host system and needs to be accessible from the RPi4:

1. **Local Testing**: If running the simulator on the same machine as the RPi4 emulator, use `localhost` or `127.0.0.1`
2. **Network Testing**: If the RPi4 is on a separate machine, ensure the simulator host is reachable via network
3. **Firewall**: Ensure port 5000 is accessible through any firewalls

### RPi4 Network Configuration

The RPi4 UEFI firmware includes:

- **Network Stack**: Full TCP/IP networking support
- **DHCP Client**: Automatic IP configuration
- **DNS Resolution**: For hostname-based service discovery
- **HTTP Client**: For Redfish protocol communication

## Troubleshooting

### Common Issues

1. **Simulator Not Starting**
   - Check Python dependencies: `pip3 install -r requirements.txt`
   - Verify port 5000 is available: `netstat -an | grep 5000`

2. **RPi4 Cannot Connect**
   - Verify network connectivity from RPi4 to simulator host
   - Check firewall settings on simulator host
   - Ensure simulator is running: `make simulator-status`

3. **Authentication Failures**
   - Verify credentials match simulator defaults (`root`/`password123456`)
   - Check EFI variable configuration if using custom credentials

4. **BIOS Synchronization Not Working**
   - Verify RedfishClientPkg drivers are properly loaded
   - Check Redfish debug output in UEFI logs
   - Ensure proper network and service configuration

### Debug Information

Enable Redfish debugging by setting these PCDs during build:

```
--pcd gEfiRedfishPkgTokenSpaceGuid.PcdRedfishDebugCategory=1
--pcd gEfiRedfishPkgTokenSpaceGuid.PcdRedfishPlatformConfigDebugProperty=0xF
```

## Service Endpoints

The simulator provides these key endpoints:

| Endpoint | Description |
|----------|-------------|
| `/redfish/v1/` | Service root |
| `/redfish/v1/Systems/1/` | Computer system information |
| `/redfish/v1/Systems/1/Bios/` | BIOS configuration |
| `/redfish/v1/Systems/1/BootOptions/` | Boot options |
| `/redfish/v1/Systems/1/SecureBoot/` | Secure boot settings |
| `/redfish/v1/Managers/1/` | Manager (BMC) information |

## Integration Testing

### Automated Testing

Use the following sequence to test complete integration:

1. Start the simulator: `make start-simulator`
2. Build the firmware: `make build`
3. Boot the RPi4 firmware
4. Run Redfish configuration: `RedfishPlatformConfig.efi -a`
5. Reboot and verify BIOS synchronization

### Manual Testing

1. Boot to EFI Shell
2. Configure network if needed: `ifconfig -s eth0 dhcp`
3. Test connectivity: `ping <simulator-ip>`
4. Run Redfish config: `RedfishPlatformConfig.efi -s`
5. Enter simulator details when prompted
6. Exit to UEFI setup to verify BIOS settings sync

## References

- [DMTF Redfish Specification](https://www.dmtf.org/standards/redfish)
- [Redfish Profile Simulator](https://github.com/DMTF/Redfish-Profile-Simulator)
- [UEFI Redfish Client Implementation](../../docs/RedfishClient.md)

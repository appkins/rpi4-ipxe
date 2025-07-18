# RPi4 Redfish Testing Scenarios

This document outlines the different testing scenarios for the RPi4 UEFI Redfish implementation.

## Testing Levels

### Level 1: Simulator Testing (Current)
**What**: Test against DMTF Redfish Profile Simulator
**Requirements**: None (software only)
**Purpose**: Validate Redfish API structure and client connectivity

**Available Resources**:
- ✅ Service Root (`/redfish/v1/`)
- ✅ Systems Collection (`/redfish/v1/Systems/`)
- ✅ System Instance (`/redfish/v1/Systems/2M220100SL/`)
- ✅ Chassis Collection (`/redfish/v1/Chassis/`)
- ✅ Managers Collection (`/redfish/v1/Managers/`)
- ❌ BIOS Resource (not in SimpleOcpServerV1 mockup)

**What We Test**:
- Basic Redfish endpoint connectivity
- Authentication mechanisms
- JSON schema compliance
- HTTP response codes

**Limitations**:
- Static mockup data only
- No real BIOS integration
- No actual configuration changes
- No firmware synchronization

### Level 2: Emulated RPi4 Testing (Future)
**What**: Test with QEMU-emulated RPi4 running our UEFI firmware
**Requirements**: QEMU with ARM64 support, network bridge setup
**Purpose**: Test firmware Redfish client without physical hardware

**Available Resources**:
- ✅ All Level 1 resources
- ✅ BIOS Resource (`/redfish/v1/Systems/system/Bios/`)
- ✅ Boot Configuration
- ✅ Firmware-managed settings

**What We Test**:
- UEFI Redfish client initialization
- HII to Redfish mapping
- Configuration language processing
- Basic synchronization flows

**Limitations**:
- Emulated hardware only
- May not reflect all real hardware behaviors
- Network configuration complexity

### Level 3: Physical RPi4 Testing (Ultimate)
**What**: Test with actual RPi4 hardware running our UEFI firmware
**Requirements**: Physical RPi4, network connectivity, BMC or Redfish service
**Purpose**: Full end-to-end validation of Redfish implementation

**Available Resources**:
- ✅ All Level 1 & 2 resources
- ✅ Real hardware sensors
- ✅ Actual boot sequences
- ✅ Network interface management
- ✅ Real storage devices

**What We Test**:
- Complete BIOS state synchronization
- Real configuration changes
- Boot order management
- Hardware-specific features
- Performance characteristics

## Current Test Results

### Simulator Validation (Level 1) ✅

```bash
$ testing/validate-redfish-config.sh
Validating Redfish configuration...
Base URL: http://127.0.0.1:5001
Username: root

Testing /redfish/v1/... OK
Testing /redfish/v1/Systems/... OK
Testing /redfish/v1/Systems/2M220100SL/... OK
Testing /redfish/v1/Systems/2M220100SL/Bios/ (optional)... SKIPPED (not available)

All endpoints validated successfully!
Redfish service is properly configured and accessible.
```

## BIOS Resource Testing

### Why BIOS Resource Isn't Available in Simulator

The DMTF Redfish Profile Simulator uses static mockup data that doesn't include BIOS management resources because:

1. **BIOS resources are firmware-specific**: They require actual UEFI firmware integration
2. **Dynamic nature**: BIOS settings change based on actual hardware and firmware state
3. **Security considerations**: BIOS management requires authenticated firmware access
4. **Complexity**: Implementing realistic BIOS simulation would require significant firmware knowledge

### When BIOS Resource Would Be Available

The BIOS resource (`/redfish/v1/Systems/system/Bios/`) would be available when:

1. **RPi4 with UEFI firmware is running**: Our custom firmware includes Redfish BIOS feature drivers
2. **Redfish client is initialized**: Feature drivers register BIOS resource management
3. **Network connectivity**: Firmware can reach the Redfish service
4. **Proper authentication**: Firmware has credentials to access the service

### Example BIOS Resource Response (When Available)

```json
{
  "@odata.type": "#Bios.v1_0_0.Bios",
  "@odata.id": "/redfish/v1/Systems/system/Bios",
  "Id": "BIOS",
  "Name": "BIOS Configuration",
  "Description": "BIOS Configuration Current Settings",
  "Attributes": {
    "BootMode": "UEFI",
    "SecureBootEnable": true,
    "QuietBoot": false,
    "BootTimeout": 5,
    "NetworkBootEnable": true
  },
  "Actions": {
    "#Bios.ResetBios": {
      "target": "/redfish/v1/Systems/system/Bios/Actions/Bios.ResetBios"
    },
    "#Bios.ChangePassword": {
      "target": "/redfish/v1/Systems/system/Bios/Actions/Bios.ChangePassword"
    }
  }
}
```

## Next Steps for BIOS Testing

### Option 1: Enhanced Simulator (Recommended for Development)
Create a custom simulator that includes BIOS resources:

```bash
# Future enhancement
./testing/create-bios-simulator.sh --with-bios --rpi4-config
```

### Option 2: QEMU Emulation (Advanced Testing)
Set up QEMU with our UEFI firmware:

```bash
# Future enhancement
./testing/setup-qemu-testing.sh --firmware-path Build/RPi4/RELEASE_GCC5/FV/RPI_EFI.fd
```

### Option 3: Physical Hardware (Production Validation)
Boot RPi4 with our firmware and test real BIOS synchronization:

1. Flash firmware to RPi4
2. Configure network connectivity
3. Set up Redfish service endpoint
4. Boot and observe BIOS resource provisioning

## Configuration for Each Level

### Simulator Configuration (Current)
```bash
# Configure for simulator testing
./testing/configure-redfish-client.sh --type simulator --server 127.0.0.1 --port 5001 --password password123456
```

### Future Hardware Configuration
```bash
# Configure for BMC-based discovery
./testing/configure-redfish-client.sh --type bmcd --server 192.168.1.100 --port 443

# Configure for static IP setup
./testing/configure-redfish-client.sh --type static --server 10.0.1.100 --local 10.0.1.50
```

## Conclusion

The current BIOS test failure is **expected and normal** for simulator testing. The BIOS resource requires actual UEFI firmware integration, which is only available when:

1. Our custom RPi4 UEFI firmware is running
2. The Redfish client feature drivers are initialized
3. Network connectivity to a Redfish service is established

The simulator testing validates that our configuration and connectivity setup is correct, which is the appropriate level of testing for this phase of development.

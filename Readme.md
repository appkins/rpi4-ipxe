Raspberry Pi 4 UEFI Firmware Images
===================================

[![Build status](https://img.shields.io/github/actions/workflow/status/pftf/RPi4/linux_edk2.yml?style=flat-square)](https://github.com/pftf/RPi4/actions)
[![Github stats](https://img.shields.io/github/downloads/pftf/RPi4/total.svg?style=flat-square)](https://github.com/pftf/RPi4/releases)
[![Release](https://img.shields.io/github/release-pre/pftf/RPi4?style=flat-square)](https://github.com/pftf/RPi4/releases)

# Summary

This repository contains installable builds of the official
[EDK2 Raspberry Pi 4 UEFI firmware](https://github.com/tianocore/edk2-platforms/tree/master/Platform/RaspberryPi/RPi4) with integrated **UEFI Redfish Client** support for out-of-band management capabilities.

## UEFI Redfish Implementation

This firmware includes a comprehensive implementation of the [DMTF Redfish](https://www.dmtf.org/standards/redfish) standard, enabling enterprise-grade remote management capabilities for the Raspberry Pi 4. The implementation is based on the [EDK2 Redfish Foundation](https://github.com/tianocore/edk2/blob/master/RedfishPkg/Readme.md) and [EDK2 Redfish Client](https://github.com/tianocore/edk2-redfish-client) projects.

### Key Features

- **Out-of-Band Management**: Remote configuration and monitoring of UEFI settings via RESTful APIs
- **Standards Compliance**: Full DMTF Redfish specification compliance for interoperability
- **Platform Configuration Sync**: Bidirectional synchronization between UEFI firmware and Redfish services
- **HII Integration**: Maps EDK2 Human Interface Infrastructure (HII) options to standard Redfish properties
- **Enterprise-Ready**: Suitable for edge computing, IoT gateways, and data center deployments

### Architecture Overview

The implementation consists of two main layers:

#### EDK2 Redfish Foundation Layer

- **EFI REST EX Driver**: HTTP/HTTPS communication with Redfish services
- **EFI Redfish Discover Driver**: Automatic discovery of Redfish services via Host Interface
- **Redfish Credential Driver**: Secure authentication and credential management
- **Host Interface Driver**: SMBIOS Type 42 record creation for service discovery

#### EDK2 Redfish Client Layer

- **Feature DXE Drivers**: Auto-generated drivers for specific Redfish schema management
- **Config Handler**: Central coordination of all Redfish feature drivers
- **Platform Config Protocol**: Abstraction layer for platform-specific configurations
- **JSON Schema Converters**: Automatic conversion between C structures and JSON payloads

### Supported Redfish Resources

The firmware supports management of the following Redfish resources:

- **ComputerSystem**: System-level configuration and status
- **Bios**: UEFI/BIOS settings and attributes
- **Memory**: Memory module configuration and inventory
- **Processor**: CPU configuration and information
- **BootOption**: Boot order and boot source management
- **NetworkInterface**: Network adapter configuration
- **ServiceRoot**: Top-level service information

### Configuration Language

The implementation uses the `x-UEFI-redfish` configuration language to map HII options to Redfish properties:

```c
// Example mappings
#string STR_BOOT_SOURCE_OVERRIDE_ENABLED_PROMPT #language x-UEFI-redfish-ComputerSystem.v1_0_0  "/Boot/BootSourceOverrideEnabled"
#string STR_BOOT_SOURCE_OVERRIDE_MODE_PROMPT    #language x-UEFI-redfish-ComputerSystem.v1_0_0  "/Boot/BootSourceOverrideMode"
#string STR_BOOT_SOURCE_OVERRIDE_TARGET_PROMPT  #language x-UEFI-redfish-ComputerSystem.v1_0_0  "/Boot/BootSourceOverrideTarget"
```

### Service Integration

The firmware can integrate with:

- **BMC-hosted Redfish services** via USB NIC or Ethernet interfaces
- **Network-based Redfish services** for centralized management
- **Redfish Profile Simulator** for development and testing

### Synchronization Operations

The Redfish client supports three main synchronization operations:

1. **Provisioning**: Push platform configurations to Redfish service
2. **Consumption**: Apply remote configuration changes to platform
3. **Update**: Sync configuration changes bidirectionally

### Development and Testing

The repository includes support for the [DMTF Redfish Profile Simulator](https://github.com/DMTF/Redfish-Profile-Simulator) to enable development and testing without requiring physical BMC hardware.

For detailed technical information, see the [Redfish Client documentation](redfish-client/RedfishClientPkg/Readme.md).

# Initial Notice

**PLEASE READ THE FOLLOWING:**  
🔻🔻🔻🔻🔻🔻🔻🔻🔻

- Ethernet networking support in Linux requires a recent enough kernel (version 5.7 or
  later)

- SD or wireless support in Linux also requires a recent enough kernel (version 5.12 or
  later).  
  Still, your mileage may vary as to whether these peripherals will actually be usable.

- Many drivers (GPIO, VPU, etc) are still likely to be missing from your OS, and will
  have to be provided by a third party. Please do not ask for them here, as they fall
  outside of the scope of this project.

- A 3 GB RAM limit is enforced **by default**, even if you are using a Raspberry Pi 4
  model that has 4 GB or 8 GB of RAM, on account that the OS **must** patch DMA access,
  to work around a hardware bug that is present in the Broadcom SoC.  
  For Linux this usually translates to using a recent kernel (version 5.8 or later) and
  for Windows this requires the installation of a filter driver.  
  If you are running an OS that has been adequately patched,  you can disable the 3 GB
  limit by going to `Device Manager` → `Raspberry Pi Configuration` → `Advanced Settings`
  in the UEFI settings.

- This firmware is built from the
  [official EDK2 repository](https://github.com/tianocore/edk2-platforms/tree/master/Platform/RaspberryPi/RPi4).

🔺🔺🔺🔺🔺🔺🔺🔺🔺

# Installation

- Download the latest archive from the [Releases](https://github.com/pftf/RPi4/releases)
  repository.

- Create an SD card or a USB drive, with at least one partition (it can be a regular
  partition or an [ESP](https://en.wikipedia.org/wiki/EFI_system_partition)) and format
  it to FAT16 or FAT32.

  **Note:** Booting from USB or from ESP requires a recent-enough version of the Pi
  EEPROM (as well as a recent version of the UEFI firmware). If you are using the latest
  UEFI firmware and find that booting from USB or from ESP doesn't work, please visit
  <https://github.com/raspberrypi/rpi-eeprom/releases> to update your EEPROM.

- Extract all the files from the archive onto the partition you created above.  
  Note that outside of this `Readme.md`, which you can safely remove, you should not
  change the names of the extracted files and directories.

# Usage

Insert the SD card/plug the USB drive and power up your Raspberry Pi. You should see a
multicoloured screen (which indicates that the CPU-embedded bootloader is reading the
data from the SD/USB partition) and then the Raspberry Pi black and white logo once the
UEFI firmware is ready.

At this stage, you can press <kbd>Esc</kbd> to enter the firmware setup, <kbd>F1</kbd>
to launch the UEFI Shell, or, provided you also have an UEFI bootloader on the SD
card or on a USB drive in `efi/boot/bootaa64.efi`, you can let the UEFI system run that
(which will be the default if no action is taken).

# Additional Notes

The firmware provided in the zip archive is the `RELEASE` version but you can also find
a `DEBUG` build of the firmware in the
[GitHub CI artifacts](https://github.com/pftf/RPi4/actions).

The provided firmwares should be able to auto-detect the UART being used (PL011 or mini
UART) according to whether `config.txt` contains the relevant overlay or not. The default
baudrate for serial I/O is `115200` and the console device to use under Linux is either
`/dev/ttyAMA0` when using PL011 or `/dev/ttyS0` when using miniUART.

At the moment, the published firmwares default to enforcing ACPI as well as a 3 GB RAM
limit, which is done to ensure Linux boot. These settings can be changed by going to
`Device Manager` &rarr; `Raspberry Pi Configuration` &rarr; `Advanced Configuration`.

Please visit <https://rpi4-uefi.dev/> for more information.

# Building with Redfish Support

This repository includes a comprehensive build system that automatically configures the firmware with Redfish capabilities:

## Prerequisites

- **Cross-compiler**: `aarch64-elf-gcc` (install via `brew install aarch64-elf-gcc` on macOS)
- **ACPI Compiler**: `iasl` (install via `brew install acpica` on macOS)
- **Standard tools**: `openssl`, `curl`, `zip`, `make`, `git`

## Quick Build

```bash
# Check dependencies
make check-deps

# Build firmware with Redfish support
make build
```

## Build Features

The build system automatically:

- **Configures Redfish**: Patches EDK2 platform files to enable Redfish support
- **Downloads certificates**: Fetches Microsoft Secure Boot keys and generates Platform Keys
- **Includes iPXE**: Builds network boot capabilities with SNP driver support
- **Sets up libraries**: Configures all necessary Redfish libraries and protocols
- **Creates archive**: Packages complete firmware with support files

## Build Configuration

Key build flags enabled for Redfish support:

- `REDFISH_ENABLE=TRUE`: Enables all Redfish functionality
- `NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE`: Allows HTTP for Redfish simulator testing
- `SECURE_BOOT_ENABLE=TRUE`: Enables Secure Boot with default keys
- `NETWORK_ISCSI_ENABLE=TRUE`: Enables iSCSI network boot
- `INCLUDE_TFTP_COMMAND=TRUE`: Includes TFTP client functionality

## Redfish Development

For Redfish development and testing:

```bash
# Set up development environment
make setup-redfish
make setup-keys

# Build with emulator support
make setup-edk2
make build
```

The built firmware will include all necessary components for Redfish service integration and can be used with the DMTF Redfish Profile Simulator for development purposes.

## Testing with Redfish Simulator

The project includes VSCode tasks and scripts for testing with the DMTF Redfish Profile Simulator:

```bash
# Install simulator
pip install redfishProfileSimulator

# Start simulator (using port 8000 to avoid macOS AirPlay conflicts)
cd testing/redfish-simulator
python redfishProfileSimulator.py -H localhost -p 8000

# Test basic endpoints (credentials: root/password123456)
curl -u root:password123456 http://localhost:8000/redfish/v1/
curl -u root:password123456 http://localhost:8000/redfish/v1/Systems/
curl -u root:password123456 http://localhost:8000/redfish/v1/Systems/2M220100SL/

# Test system management actions
curl -X POST -u root:password123456 -H "Content-Type: application/json" \
  -d '{"ResetType":"ForceRestart"}' \
  http://localhost:8000/redfish/v1/Systems/2M220100SL/Actions/ComputerSystem.Reset
```

**VSCode Tasks Available:**

- **Start Redfish Simulator**: Launches simulator on port 8000
- **Test Redfish Connection**: Validates basic API connectivity
- **Stop Redfish Simulator**: Terminates simulator process
- **Build UEFI Firmware**: Complete firmware build with Redfish support

# License

The firmware (`RPI_EFI.fd`) is licensed under the current EDK2 license, which is
[BSD-2-Clause-Patent](https://github.com/tianocore/edk2/blob/master/License.txt).

The other files from the zip archives are licensed under the terms described in the
[Raspberry Pi boot files README](https://github.com/raspberrypi/firmware/blob/master/README.md).

The binary blobs in the `firmware/` directory are licensed under the Cypress wireless driver
license that is found there.

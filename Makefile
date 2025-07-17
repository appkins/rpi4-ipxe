# Copyright (c) 2021-2024, Pete Batard <pete@akeo.ie>
# SPDX-License-Identifier: BSD-3-Clause

# Makefile for RPi4 UEFI firmware build
# Converted from .github/workflows/linux_edk2.yml

# Configuration variables
PROJECT_URL := https://github.com/pftf/RPi4
RPI_FIRMWARE_URL := https://github.com/raspberrypi/firmware/
ARCH := AARCH64
COMPILER := GCC5
GCC5_AARCH64_PREFIX ?= $(shell echo $${GCC5_AARCH64_PREFIX:-aarch64-elf-})
START_ELF_VERSION := master
DTB_VERSION := b49983637106e5fb33e2ae60d8c15a53187541e4
DTBO_VERSION := master

# Version can be overridden via environment variable
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo "dev")

# Directories
WORKSPACE := $(PWD)
KEYS_DIR := keys
OVERLAYS_DIR := overlays
BUILD_DIR := Build/RPi4/RELEASE_$(COMPILER)
FIRMWARE_DIR := $(BUILD_DIR)/FV

# Generated files
FIRMWARE_FILE := $(FIRMWARE_DIR)/RPI_EFI.fd
FIRMWARE_COPY := armstub8.bin
ARCHIVE_FILE := RPi4_UEFI_Firmware_$(VERSION).zip

# Key files
KEY_FILES := $(KEYS_DIR)/pk.cer \
             $(KEYS_DIR)/ms_kek1.cer \
             $(KEYS_DIR)/ms_kek2.cer \
             $(KEYS_DIR)/ms_db1.cer \
             $(KEYS_DIR)/ms_db2.cer \
             $(KEYS_DIR)/ms_db3.cer \
             $(KEYS_DIR)/ms_db4.cer \
             $(KEYS_DIR)/arm64_dbx.bin

# Raspberry Pi support files
RPI_FILES := fixup4.dat \
             start4.elf \
             bcm2711-rpi-4-b.dtb \
             bcm2711-rpi-cm4.dtb \
             bcm2711-rpi-400.dtb

# Overlay files
OVERLAY_FILES := $(OVERLAYS_DIR)/miniuart-bt.dtbo \
                 $(OVERLAYS_DIR)/upstream-pi4.dtbo

# Build flags
PACKAGES_PATH := $(WORKSPACE)/edk2:$(WORKSPACE)/platforms:$(WORKSPACE)/non-osi:$(WORKSPACE):$(WORKSPACE)/redfish-client
BUILD_FLAGS := -D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE \
               -D REDFISH_ENABLE=TRUE \
							 -D NDEBUG=TRUE \
               -D SECURE_BOOT_ENABLE=TRUE \
               -D INCLUDE_TFTP_COMMAND=TRUE \
               -D NETWORK_ISCSI_ENABLE=TRUE \
               -D SMC_PCI_SUPPORT=1
TLS_DISABLE_FLAGS := -D NETWORK_TLS_ENABLE=FALSE \
                     -D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE
DEFAULT_KEYS := -D DEFAULT_KEYS=TRUE \
                -D PK_DEFAULT_FILE=$(WORKSPACE)/$(KEYS_DIR)/pk.cer \
                -D KEK_DEFAULT_FILE1=$(WORKSPACE)/$(KEYS_DIR)/ms_kek1.cer \
                -D KEK_DEFAULT_FILE2=$(WORKSPACE)/$(KEYS_DIR)/ms_kek2.cer \
                -D DB_DEFAULT_FILE1=$(WORKSPACE)/$(KEYS_DIR)/ms_db1.cer \
                -D DB_DEFAULT_FILE2=$(WORKSPACE)/$(KEYS_DIR)/ms_db2.cer \
                -D DB_DEFAULT_FILE3=$(WORKSPACE)/$(KEYS_DIR)/ms_db3.cer \
                -D DB_DEFAULT_FILE4=$(WORKSPACE)/$(KEYS_DIR)/ms_db4.cer \
                -D DBX_DEFAULT_FILE1=$(WORKSPACE)/$(KEYS_DIR)/arm64_dbx.bin

# Default target
.PHONY: all
all: $(ARCHIVE_FILE)

# Check for required tools
.PHONY: check-deps
check-deps:
	@echo "Checking dependencies..."
	@command -v openssl >/dev/null 2>&1 || { echo "Error: openssl not found"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "Error: curl not found"; exit 1; }
	@command -v zip >/dev/null 2>&1 || { echo "Error: zip not found"; exit 1; }
	@command -v make >/dev/null 2>&1 || { echo "Error: make not found"; exit 1; }
	@command -v sed >/dev/null 2>&1 || { echo "Error: sed not found"; exit 1; }
	@command -v grep >/dev/null 2>&1 || { echo "Error: grep not found"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "Error: git not found"; exit 1; }
	@command -v sha256sum >/dev/null 2>&1 || { echo "Error: sha256sum not found"; exit 1; }
	@command -v $(GCC5_AARCH64_PREFIX)gcc >/dev/null 2>&1 || { echo "Error: $(GCC5_AARCH64_PREFIX)gcc not found. Install with: brew install aarch64-elf-gcc"; exit 1; }
	@command -v $(GCC5_AARCH64_PREFIX)gcc-ar >/dev/null 2>&1 || { echo "Error: $(GCC5_AARCH64_PREFIX)gcc-ar not found. Install with: brew install aarch64-elf-gcc"; exit 1; }
	@command -v iasl >/dev/null 2>&1 || { echo "Error: iasl not found. Install with: brew install acpica"; exit 1; }

# Set up Redfish in UEFI firmware
.PHONY: setup-redfish
setup-redfish:
	@echo "Setting up Redfish in UEFI firmware..."
	@grep -qF -- "!include RedfishPkg/RedfishComponents.dsc.inc" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '742a \!include RedfishPkg/RedfishComponents.dsc.inc' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '177a \  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib/PlatformHostInterfaceBmcUsbNicLib.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '177a \  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib/PlatformHostInterfaceBmcUsbNicLib.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  RedfishPlatformWantedDeviceLib|RedfishPkg/Library/RedfishPlatformWantedDeviceLibNull/RedfishPlatformWantedDeviceLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '169a \  RedfishPlatformWantedDeviceLib|RedfishPkg/Library/RedfishPlatformWantedDeviceLibNull/RedfishPlatformWantedDeviceLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceLibNull/PlatformHostInterfaceLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '169a \  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceLibNull/PlatformHostInterfaceLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '169a \  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  IpmiCommandLib|MdeModulePkg/Library/BaseIpmiCommandLibNull/BaseIpmiCommandLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '169a \  IpmiCommandLib|MdeModulePkg/Library/BaseIpmiCommandLibNull/BaseIpmiCommandLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  IpmiLib|MdeModulePkg/Library/BaseIpmiLibNull/BaseIpmiLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '169a \  IpmiLib|MdeModulePkg/Library/BaseIpmiLibNull/BaseIpmiLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "!include RedfishPkg/RedfishLibs.dsc.inc" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '57a \!include RedfishPkg/RedfishLibs.dsc.inc' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  DEFINE REDFISH_CLIENT_ALL_AUTOGENED = TRUE" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '34a \  DEFINE REDFISH_CLIENT_ALL_AUTOGENED = TRUE' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "  DEFINE REDFISH_ENABLE          = TRUE" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || \
		sed -i '34a \  DEFINE REDFISH_ENABLE          = TRUE' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@grep -qF -- "!include RedfishPkg/Redfish.fdf.inc" platforms/Platform/RaspberryPi/RPi4/RPi4.fdf || \
		sed -i '321a \!include RedfishPkg/Redfish.fdf.inc' platforms/Platform/RaspberryPi/RPi4/RPi4.fdf
	@sed -i 's#gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB|L"RamMoreThan3GB"|gConfigDxeFormSetGuid|0x0|0#gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB|L"RamMoreThan3GB"|gConfigDxeFormSetGuid|0x0|1#g' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@sed -i 's#gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB|L"RamLimitTo3GB"|gConfigDxeFormSetGuid|0x0|1#gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB|L"RamLimitTo3GB"|gConfigDxeFormSetGuid|0x0|0#g' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
	@echo "Patching JsonLib for NDEBUG build compatibility..."
	@if grep -q "#ifndef NDEBUG" edk2/RedfishPkg/Library/JsonLib/load.c; then \
		sed -i '338d' edk2/RedfishPkg/Library/JsonLib/load.c; \
		sed -i '336d' edk2/RedfishPkg/Library/JsonLib/load.c; \
		sed -i '334d' edk2/RedfishPkg/Library/JsonLib/load.c; \
		sed -i '332d' edk2/RedfishPkg/Library/JsonLib/load.c; \
		echo "JsonLib already fixed or does not need patching"; \
	fi

# Set up EDK2 BaseTools
.PHONY: setup-edk2
setup-edk2:
	@echo "Setting up EDK2 BaseTools..."
	$(MAKE) -C edk2/BaseTools
	@echo "EDK2 BaseTools setup complete"

# Create keys directory
$(KEYS_DIR):
	mkdir -p $(KEYS_DIR)

# Set up Secure Boot default keys
$(KEYS_DIR)/pk.cer: | $(KEYS_DIR)
	@echo "Generating Platform Key..."
	openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Raspberry Pi Platform Key/" \
		-keyout /dev/null -outform DER -out $@ -days 7300 -nodes -sha256

$(KEYS_DIR)/ms_kek1.cer: | $(KEYS_DIR)
	@echo "Downloading Microsoft KEK 1..."
	curl -L https://go.microsoft.com/fwlink/?LinkId=321185 -o $@

$(KEYS_DIR)/ms_kek2.cer: | $(KEYS_DIR)
	@echo "Downloading Microsoft KEK 2..."
	curl -L https://go.microsoft.com/fwlink/?linkid=2239775 -o $@

$(KEYS_DIR)/ms_db1.cer: | $(KEYS_DIR)
	@echo "Downloading Microsoft DB 1..."
	curl -L https://go.microsoft.com/fwlink/?linkid=321192 -o $@

$(KEYS_DIR)/ms_db2.cer: | $(KEYS_DIR)
	@echo "Downloading Microsoft DB 2..."
	curl -L https://go.microsoft.com/fwlink/?linkid=321194 -o $@

$(KEYS_DIR)/ms_db3.cer: | $(KEYS_DIR)
	@echo "Downloading Microsoft DB 3..."
	curl -L https://go.microsoft.com/fwlink/?linkid=2239776 -o $@

$(KEYS_DIR)/ms_db4.cer: | $(KEYS_DIR)
	@echo "Downloading Microsoft DB 4..."
	curl -L https://go.microsoft.com/fwlink/?linkid=2239872 -o $@

$(KEYS_DIR)/arm64_dbx.bin: | $(KEYS_DIR)
	@echo "Downloading ARM64 DBX..."
	curl -L https://uefi.org/sites/default/files/resources/dbxupdate_arm64.bin -o $@

# Set up all keys
.PHONY: setup-keys
setup-keys: $(KEY_FILES)

# Build UEFI firmware
$(FIRMWARE_FILE): setup-edk2 setup-redfish $(KEY_FILES)
	@echo "Building UEFI firmware..."
	export WORKSPACE=$(WORKSPACE) && \
	export PACKAGES_PATH="$(PACKAGES_PATH)" && \
	export GCC5_AARCH64_PREFIX="$(GCC5_AARCH64_PREFIX)" && \
	. edk2/edksetup.sh && \
	build -a $(ARCH) -t $(COMPILER) -b RELEASE \
		-p platforms/Platform/RaspberryPi/RPi4/RPi4.dsc \
		--pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"$(PROJECT_URL)" \
		--pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"UEFI Firmware $(VERSION)" \
		$(BUILD_FLAGS) $(DEFAULT_KEYS) $(TLS_DISABLE_FLAGS)

# Copy firmware to root directory
$(FIRMWARE_COPY): $(FIRMWARE_FILE)
	@echo "Copying firmware to root directory..."
	cp $(FIRMWARE_FILE) $(FIRMWARE_COPY)

# Download Raspberry Pi support files
fixup4.dat:
	@echo "Downloading fixup4.dat..."
	curl -O -L $(RPI_FIRMWARE_URL)/raw/$(START_ELF_VERSION)/boot/fixup4.dat

start4.elf:
	@echo "Downloading start4.elf..."
	curl -O -L $(RPI_FIRMWARE_URL)/raw/$(START_ELF_VERSION)/boot/start4.elf

bcm2711-rpi-4-b.dtb:
	@echo "Downloading bcm2711-rpi-4-b.dtb..."
	curl -O -L $(RPI_FIRMWARE_URL)/raw/$(DTB_VERSION)/boot/bcm2711-rpi-4-b.dtb

bcm2711-rpi-cm4.dtb:
	@echo "Downloading bcm2711-rpi-cm4.dtb..."
	curl -O -L $(RPI_FIRMWARE_URL)/raw/$(DTB_VERSION)/boot/bcm2711-rpi-cm4.dtb

bcm2711-rpi-400.dtb:
	@echo "Downloading bcm2711-rpi-400.dtb..."
	curl -O -L $(RPI_FIRMWARE_URL)/raw/$(DTB_VERSION)/boot/bcm2711-rpi-400.dtb

# Create overlays directory
$(OVERLAYS_DIR):
	mkdir -p $(OVERLAYS_DIR)

$(OVERLAYS_DIR)/miniuart-bt.dtbo: | $(OVERLAYS_DIR)
	@echo "Downloading miniuart-bt.dtbo..."
	curl -L $(RPI_FIRMWARE_URL)/raw/$(DTBO_VERSION)/boot/overlays/miniuart-bt.dtbo -o $@

$(OVERLAYS_DIR)/upstream-pi4.dtbo: | $(OVERLAYS_DIR)
	@echo "Downloading upstream-pi4.dtbo..."
	curl -L $(RPI_FIRMWARE_URL)/raw/$(DTBO_VERSION)/boot/overlays/upstream-pi4.dtbo -o $@

# Download all Raspberry Pi support files
.PHONY: download-rpi-files
download-rpi-files: $(RPI_FILES) $(OVERLAY_FILES)

# Create UEFI firmware archive
$(ARCHIVE_FILE): $(FIRMWARE_COPY) $(RPI_FILES) $(OVERLAY_FILES) config.txt Readme.md
	@echo "Creating UEFI firmware archive..."
	zip -r $(ARCHIVE_FILE) $(FIRMWARE_COPY) $(RPI_FILES) config.txt $(OVERLAYS_DIR) Readme.md firmware efi

# Display SHA-256 checksums
.PHONY: checksums
checksums: $(FIRMWARE_FILE) $(ARCHIVE_FILE)
	@echo "SHA-256 checksums:"
	sha256sum $(FIRMWARE_FILE) $(ARCHIVE_FILE)

# Build everything
.PHONY: build
build: check-deps $(FIRMWARE_COPY) download-rpi-files $(ARCHIVE_FILE) checksums

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf Build/
	rm -f $(FIRMWARE_COPY)
	rm -f $(ARCHIVE_FILE)
	rm -f $(RPI_FILES)
	rm -rf $(OVERLAYS_DIR)

# Clean everything including keys
.PHONY: distclean
distclean: clean
	@echo "Cleaning all generated files..."
	rm -rf $(KEYS_DIR)

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all            - Build everything (default)"
	@echo "  build          - Build firmware and create archive"
	@echo "  check-deps     - Check for required dependencies"
	@echo "  setup-redfish  - Set up Redfish configuration in DSC files"
	@echo "  setup-edk2     - Build EDK2 BaseTools"
	@echo "  setup-keys     - Download and generate all security keys"
	@echo "  download-rpi-files - Download Raspberry Pi support files"
	@echo "  checksums      - Display SHA-256 checksums"
	@echo "  clean          - Clean build artifacts"
	@echo "  distclean      - Clean everything including keys"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  VERSION        - Version string (default: git describe or 'dev')"
	@echo ""
	@echo "Key files generated in keys/ directory:"
	@echo "  pk.cer         - Platform Key (self-generated)"
	@echo "  ms_kek*.cer    - Microsoft Key Exchange Keys"
	@echo "  ms_db*.cer     - Microsoft Database Keys"
	@echo "  arm64_dbx.bin  - ARM64 Forbidden Signatures Database"

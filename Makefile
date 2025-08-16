# Makefile for RPi4 UEFI firmware build with Redfish integration

BUILD_TYPE ?= RELEASE

# Configuration variables
PROJECT_URL := https://github.com/pftf/RPi4
ARCH := AARCH64
COMPILER := GCC5
GCC5_AARCH64_PREFIX ?= $(shell echo $${GCC5_AARCH64_PREFIX:-aarch64-elf-})
START_ELF_VERSION := master
DTB_VERSION := b49983637106e5fb33e2ae60d8c15a53187541e4
DTBO_VERSION := master
RPI_FIRMWARE_VERSION := master
RPI_FIRMWARE_URL := https://github.com/raspberrypi/firmware/raw/$(RPI_FIRMWARE_VERSION)/boot
BRCM_FIRMWARE_URL := https://archive.raspberrypi.org/debian/pool/main/f/firmware-nonfree/firmware-brcm80211_20240709-2~bpo12+1+rpt3_all.deb

# Version can be overridden via environment variable
VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo "dev")

# Directories
WORKSPACE := $(PWD)
KEYS_DIR := keys
BUILD_DIR := Build
ARCHIVE_DIR := $(BUILD_DIR)/archive
FIRMWARE_DIR := $(BUILD_DIR)/RPi4/$(BUILD_TYPE)_$(COMPILER)/FV
OVERLAYS_DIR := $(ARCHIVE_DIR)/overlays
BRCM_DIR := $(ARCHIVE_DIR)/firmware
TEMPLATES_DIR := templates

# Generated files
ARCHIVE_FILE := RPi4_UEFI_Firmware_$(VERSION).zip
IMAGE_FILE := RPi4_UEFI_Firmware_$(VERSION).img
DMG_FILE := $(addsuffix .dmg, $(basename $(IMAGE_FILE)))
FIRMWARE_FILE := $(FIRMWARE_DIR)/RPI_EFI.fd
BRCM_DEB_FILE := $(BRCM_DIR)/$(notdir $(BRCM_FIRMWARE_URL))
BRCM_ARCHIVE := $(BRCM_DIR)/data.tar.xz

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
OVERLAY_FILES := miniuart-bt.dtbo \
                 upstream-pi4.dtbo

# Broadcom firmware files
BRCM_FILES := brcmfmac43455-sdio.bin \
			  brcmfmac43455-sdio.clm_blob \
			  brcmfmac43455-sdio.txt

RPI_FILES := $(addprefix $(ARCHIVE_DIR)/, $(RPI_FILES))
OVERLAY_FILES := $(addprefix $(OVERLAYS_DIR)/, $(OVERLAY_FILES))
BRCM_FILES := $(addprefix $(BRCM_DIR)/, $(BRCM_FILES))

# Build flags
PACKAGES_PATH := $(WORKSPACE)/edk2:$(WORKSPACE)/platforms:$(WORKSPACE)/non-osi:$(WORKSPACE)
BUILD_FLAGS := -D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE \
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
all: $(FIRMWARE_FILE) $(BUILD_DIR)/$(ARCHIVE_FILE)

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
	@command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found. Install Python 3.x"; exit 1; }

# Apply template overlays to platforms directory
.PHONY: apply-templates
apply-templates:
	@echo "Applying template overlays to platforms directory..."
	@echo "Copying $(TEMPLATES_DIR)/* with Redfish enhancements..."
	@echo "cp -r $(TEMPLATES_DIR)/* platforms/"

# Set up EDK2 BaseTools
.PHONY: setup-edk2
setup-edk2:
	@echo "Setting up EDK2 BaseTools..."
	@echo "Using native macOS toolchain for BaseTools..."
	PATH="/usr/bin:/bin:/usr/sbin:/sbin" $(MAKE) -C edk2/BaseTools CC=clang CXX=clang++ AR=/usr/bin/ar RANLIB=/usr/bin/ranlib
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
$(FIRMWARE_FILE): | setup-edk2 apply-templates $(KEY_FILES)
	@echo "Building UEFI firmware with Redfish early synchronization support..."
	export WORKSPACE=$(WORKSPACE) && \
	export PACKAGES_PATH="$(PACKAGES_PATH)" && \
	export GCC5_AARCH64_PREFIX="$(GCC5_AARCH64_PREFIX)" && \
	. edk2/edksetup.sh && \
	build -a $(ARCH) -t $(COMPILER) -b $(BUILD_TYPE) \
		-p platforms/Platform/RaspberryPi/RPi4/RPi4.dsc \
    --pcd gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB=1 \
    --pcd gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB=0 \
    --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdBootDiscoveryPolicy=2 \
    --pcd gRaspberryPiTokenSpaceGuid.PcdSystemTableMode=1 \
		--pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"$(PROJECT_URL)" \
		--pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"UEFI Firmware $(VERSION)" \
		$(BUILD_FLAGS) $(DEFAULT_KEYS) $(TLS_DISABLE_FLAGS)

$(BRCM_DIR):
	mkdir -p $@

$(BRCM_DEB_FILE): $(BRCM_DIR)
	@echo "Downloading Broadcom firmware..."
	curl -L $(BRCM_FIRMWARE_URL) -o $@

$(BRCM_ARCHIVE): $(BRCM_DEB_FILE)
	@echo "Extracting Broadcom firmware archive..."
	cd $(BRCM_DIR) && \
	ar -x $(notdir $<) data.tar.xz && \
	rm $(notdir $<)

$(BRCM_FILES): $(BRCM_ARCHIVE)
	@echo "Extracting Broadcom firmware files..."
	cd $(dir $@) && \
	tar --strip-components 3 -zxvf $(notdir $<) lib/firmware

.PHONY: clean-brcm
clean-brcm:
	@echo "Cleaning Broadcom firmware..."
	rm $(BRCM_ARCHIVE)

.PHONY: setup-brcm
setup-brcm: $(BRCM_ARCHIVE)
	@echo "Extracting Broadcom firmware files..."
	cd $(BRCM_DIR) && \
	tar --strip-components 3 -xvf $(notdir $<) lib/firmware
	rm $(BRCM_ARCHIVE)

# Download Raspberry Pi support files
$(RPI_FILES): | $(ARCHIVE_DIR)
	@echo "Downloading $(notdir $@)..."
	curl -o $@ -L $(RPI_FIRMWARE_URL)/$(notdir $@)

# Create overlays directory
$(OVERLAYS_DIR):
	mkdir -p $@

$(OVERLAY_FILES): $(OVERLAYS_DIR)
	@echo "Downloading $(notdir $@)..."
	curl -L $(RPI_FIRMWARE_URL)/overlays/$(notdir $@) -o $@

# Download all Raspberry Pi support files
.PHONY: download-rpi-files
download-rpi-files: $(RPI_FILES) $(OVERLAY_FILES)

$(ARCHIVE_DIR):
	mkdir -p $(ARCHIVE_DIR)

$(ARCHIVE_DIR)/config.txt:
	cp config.txt $(ARCHIVE_DIR)/config.txt

$(ARCHIVE_DIR)/Readme.md:
	cp Readme.md $(ARCHIVE_DIR)/Readme.md

# Copy firmware to root directory
$(ARCHIVE_DIR)/RPI_EFI.fd: $(FIRMWARE_FILE) | $(ARCHIVE_DIR)
	@echo "Copying firmware to root directory..."
	cp $(FIRMWARE_FILE) $(ARCHIVE_DIR)/RPI_EFI.fd

$(BUILD_DIR)/$(IMAGE_FILE): $(BUILD_DIR)/$(ARCHIVE_FILE)
	@echo "Creating disk image from firmware archive..."
	@echo "Converting $(BUILD_DIR)/$(ARCHIVE_FILE) to $(BUILD_DIR)/$(IMAGE_FILE)..."
	if [ -f $(BUILD_DIR)/$(DMG_FILE) ]; then rm -f $(BUILD_DIR)/$(DMG_FILE); fi
	hdiutil create -volname RPI_BOOT -fs MS-DOS -srcfolder $(ARCHIVE_DIR) $(BUILD_DIR)/$(DMG_FILE)
	if [ -f $(BUILD_DIR)/$(IMAGE_FILE).dmg ]; then rm -f $(BUILD_DIR)/$(IMAGE_FILE).dmg; fi
	hdiutil convert $(BUILD_DIR)/$(DMG_FILE) -format UDRW -o $(BUILD_DIR)/$(IMAGE_FILE).dmg
	mv $(BUILD_DIR)/$(IMAGE_FILE).dmg $(BUILD_DIR)/$(IMAGE_FILE)
	@echo "Creating final image file..."
	@echo "Using hdiutil to create image file..."

.PHONY: flash-ssd
flash-ssd: $(BUILD_DIR)/$(ARCHIVE_FILE)
	@echo "Flashing image to device..."
	@echo "Use the following command to flash the image:"
	@echo "Eject the SD card before flashing!"
	diskutil eraseDisk FAT32 BOOT MBRFormat "$(shell diskutil list external physical | grep -E '^/' | cut -d' ' -f1 | head -n1)"
	cp -rf $(ARCHIVE_DIR)/* /Volumes/BOOT/

.PHONY: unmount-disk
unmount-disk: flash-ssd
	@echo "Unmounting disk..."
	diskutil unmountDisk "$(shell diskutil list external physical | grep -E '^/' | cut -d' ' -f1 | head -n1)"

.PHONY: copy-ssd
copy-ssd: $(FIRMWARE_FILE)
	cp $(FIRMWARE_FILE) /Volumes/BOOT/RPI_EFI.fd
	diskutil unmountDisk "$(shell diskutil list external physical | grep -E '^/' | cut -d' ' -f1 | head -n1)"

# Create UEFI firmware archive
$(BUILD_DIR)/$(ARCHIVE_FILE): $(ARCHIVE_DIR) $(ARCHIVE_DIR)/RPI_EFI.fd setup-brcm $(RPI_FILES) $(OVERLAY_FILES) $(ARCHIVE_DIR)/config.txt $(ARCHIVE_DIR)/Readme.md
	@echo "Creating UEFI firmware archive..."
	cd $(ARCHIVE_DIR) && \
	zip -r ../../$@ RPI_EFI.fd $(notdir $(RPI_FILES)) config.txt overlays Readme.md firmware efi

# Display SHA-256 checksums
.PHONY: checksums
checksums: $(FIRMWARE_FILE) $(BUILD_DIR)/$(ARCHIVE_FILE)
	@echo "SHA-256 checksums:"
	sha256sum $(FIRMWARE_FILE) $(BUILD_DIR)/$(ARCHIVE_FILE)

# Build everything
.PHONY: build
build: check-deps $(ARCHIVE_DIR)/RPI_EFI.fd download-rpi-files setup-brcm $(BUILD_DIR)/$(ARCHIVE_FILE) checksums

# Clean platforms submodule to remote state
.PHONY: clean-platforms
clean-platforms:
	@echo "Resetting platforms submodule to remote state..."
	git submodule update --init --force platforms
	cd platforms && git clean -fd && git reset --hard HEAD

# Clean build artifacts
.PHONY: clean
clean: clean-platforms
	@echo "Cleaning build artifacts..."
	for mod in $$(cat .gitmodules | grep path | cut -d'=' -f 2 | tr -d ' '); do \
    git submodule update --init --force "$${mod}" && \
    cd "$${mod}" && \
    git clean -fd && \
	  git reset --hard HEAD && \
	  cd ..; \
	done
	rm -rf Build/
	rm -rf firmware/build

# Clean everything including keys
.PHONY: distclean
distclean: clean
	@echo "Cleaning all generated files..."
	rm -rf $(KEYS_DIR)

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all                - Build everything (default)"
	@echo "  build              - Build firmware and create archive"
	@echo "  check-deps         - Check for required dependencies"
	@echo "  apply-templates    - Apply template overlays to platforms directory"
	@echo "  setup-edk2         - Build EDK2 BaseTools"
	@echo "  setup-keys         - Download and generate all security keys"
	@echo "  setup-firmware     - Set up Trusted Firmware for Raspberry Pi"
	@echo "  download-rpi-files - Download Raspberry Pi support files"
	@echo "  checksums          - Display SHA-256 checksums"
	@echo ""
	@echo "Cleanup targets:"
	@echo "  clean              - Clean build artifacts and reset platforms"
	@echo "  clean-platforms    - Reset platforms submodule to remote state"
	@echo "  distclean          - Clean everything including keys"
	@echo "  help               - Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  VERSION        - Version string (default: git describe or 'dev')"
	@echo ""
	@echo "Key files generated in keys/ directory:"
	@echo "  pk.cer         - Platform Key (self-generated)"
	@echo "  ms_kek*.cer    - Microsoft Key Exchange Keys"
	@echo "  ms_db*.cer     - Microsoft Database Keys"
	@echo "  arm64_dbx.bin  - ARM64 Forbidden Signatures Database"

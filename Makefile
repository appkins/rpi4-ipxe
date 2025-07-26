# Makefile for RPi4 UEFI firmware build with Redfish integration

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
FIRMWARE_DIR := $(BUILD_DIR)/RPi4/RELEASE_$(COMPILER)/FV
OVERLAYS_DIR := $(ARCHIVE_DIR)/overlays
BRCM_DIR := $(ARCHIVE_DIR)/firmware
IPXE_DIR := ipxe/src
IPXE_LOCAL_DIR := $(IPXE_DIR)/config/local
TEMPLATES_DIR := templates
SIMULATOR_DIR := redfish-client/Tools/Redfish-Profile-Simulator

# Generated files
ARCHIVE_FILE := RPi4_UEFI_Firmware_$(VERSION).zip
IMAGE_FILE := RPi4_UEFI_Firmware_$(VERSION).img
DMG_FILE := $(addsuffix .dmg, $(basename $(IMAGE_FILE)))
FIRMWARE_FILE := $(FIRMWARE_DIR)/RPI_EFI.fd
BRCM_DEB_FILE := $(BRCM_DIR)/$(notdir $(BRCM_FIRMWARE_URL))
BRCM_ARCHIVE := $(BRCM_DIR)/data.tar.xz
SIMULATOR_PID_FILE := $(BUILD_DIR)/simulator.pid

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
PACKAGES_PATH := $(WORKSPACE)/edk2:$(WORKSPACE)/platforms:$(WORKSPACE)/non-osi:$(WORKSPACE):$(WORKSPACE)/redfish-client
BUILD_FLAGS := -D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE \
               -D REDFISH_ENABLE=TRUE \
               -D REDFISH_CLIENT=TRUE \
               -D SECURE_BOOT_ENABLE=TRUE \
               -D INCLUDE_TFTP_COMMAND=TRUE \
               -D NETWORK_ISCSI_ENABLE=TRUE \
               -D SMC_PCI_SUPPORT=1 \
			   -D NDEBUG=FALSE
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

TRUSTED_FIRMWARE_SRC := firmware/build/rpi5/release/bl31.bin
TRUSTED_FIRMWARE_DST := templates/Platform/RaspberryPi/RPi5/TrustedFirmware/bl31.bin

# Default target
.PHONY: all
all: $(FIRMWARE_FILE) $(BUILD_DIR)/$(ARCHIVE_FILE)

$(IPXE_LOCAL_DIR):
	@echo "Creating local configuration directory..."
	@mkdir -p $(IPXE_LOCAL_DIR)

$(IPXE_LOCAL_DIR)/general.h: $(IPXE_LOCAL_DIR)
	@echo "Creating general.h file..."
	@echo "#define NSLOOKUP_CMD" > $@
	@echo "#define PING_CMD" >> $@
	@echo "#define NTP_CMD" >> $@
	@echo "#define VLAN_CMD" >> $@
	@echo "#define IMAGE_EFI" >> $@
	@echo "#define DOWNLOAD_PROTO_HTTPS" >> $@
	@echo "#define DOWNLOAD_PROTO_FTP" >> $@
	@echo "#define DOWNLOAD_PROTO_NFS" >> $@
	@echo "#define DOWNLOAD_PROTO_FILE" >> $@

$(IPXE_DIR)/bin-arm64-efi/snp.efi: $(IPXE_LOCAL_DIR)/general.h
	@echo "Building iPXE SNP driver..."
	export C_INCLUDE_PATH="/opt/homebrew/opt/aarch64-elf-gcc/lib/gcc/aarch64-elf/15.1.0/include" && \
	$(MAKE) -C $(IPXE_DIR) \
		bin-arm64-efi/snp.efi \
		-j4 \
		CONFIG=rpi \
		CROSS=$(GCC5_AARCH64_PREFIX)

.PHONY: setup-ipxe
setup-ipxe: $(IPXE_DIR)/bin-arm64-efi/snp.efi

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
	@echo "Copying $(TEMPLATES_DIR) with Redfish enhancements..."
	@cp -r $(TEMPLATES_DIR)/* platforms/

# Set up EDK2 BaseTools
.PHONY: setup-edk2
setup-edk2:
	@echo "Setting up EDK2 BaseTools..."
	@echo "Using native macOS toolchain for BaseTools..."
	PATH="/usr/bin:/bin:/usr/sbin:/sbin" $(MAKE) -C edk2/BaseTools CC=clang CXX=clang++ AR=/usr/bin/ar RANLIB=/usr/bin/ranlib
	@echo "EDK2 BaseTools setup complete"

$(TRUSTED_FIRMWARE_SRC):
	@cd firmware && \
	CROSS_COMPILE=$(GCC5_AARCH64_PREFIX) \
	$(MAKE) \
		PLAT=rpi5 \
		RPI3_PRELOADED_DTB_BASE=0x1F0000 \
		PRELOADED_BL33_BASE=0x20000 \
		SUPPORT_VFP=1 \
		SMC_PCI_SUPPORT=1 \
		DEBUG=0 \
		all

$(TRUSTED_FIRMWARE_DST): $(TRUSTED_FIRMWARE_SRC)
	@echo "Creating $@..."
	@echo "Source $<"
	@mkdir -p $(dir $@)
	@cp $< $@

.PHONY: setup-firmware
setup-firmware: $(TRUSTED_FIRMWARE_DST)

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

# Redfish Profile Simulator targets
.PHONY: setup-simulator
setup-simulator:
	@echo "Setting up Redfish Profile Simulator..."
	@if [ ! -d $(SIMULATOR_DIR)/venv ]; then \
		echo "Creating Python virtual environment..."; \
		cd $(SIMULATOR_DIR) && python3 -m venv venv; \
	fi
	@echo "Installing dependencies in virtual environment..."
	@cd $(SIMULATOR_DIR) && source venv/bin/activate && pip install -r requirements.txt
	@echo "Simulator setup complete"

.PHONY: start-simulator
start-simulator: setup-simulator
	@echo "Starting Redfish Profile Simulator..."
	@if [ -f $(SIMULATOR_PID_FILE) ] && kill -0 `cat $(SIMULATOR_PID_FILE)` 2>/dev/null; then \
		echo "Simulator is already running (PID: `cat $(SIMULATOR_PID_FILE)`)"; \
	else \
		mkdir -p $(BUILD_DIR); \
		cd $(SIMULATOR_DIR) && source venv/bin/activate && nohup python redfishProfileSimulator.py -H 0.0.0.0 -P 5000 > $(WORKSPACE)/$(BUILD_DIR)/simulator.log 2>&1 & \
		echo $$! > $(WORKSPACE)/$(BUILD_DIR)/simulator.pid && \
		echo "Simulator started (PID: $$!) on http://localhost:5000/redfish/v1/"; \
		echo "Credentials: admin/pwd123456 or root/password123456 (for sessions)"; \
		echo "Log file: $(BUILD_DIR)/simulator.log"; \
	fi

.PHONY: stop-simulator
stop-simulator:
	@echo "Stopping Redfish Profile Simulator..."
	@if [ -f $(SIMULATOR_PID_FILE) ]; then \
		if kill -0 `cat $(SIMULATOR_PID_FILE)` 2>/dev/null; then \
			kill `cat $(SIMULATOR_PID_FILE)` && \
			echo "Simulator stopped"; \
		else \
			echo "Simulator was not running"; \
		fi; \
		rm -f $(SIMULATOR_PID_FILE); \
	else \
		echo "No PID file found - simulator may not be running"; \
	fi

.PHONY: simulator-status
simulator-status:
	@if [ -f $(SIMULATOR_PID_FILE) ] && kill -0 `cat $(SIMULATOR_PID_FILE)` 2>/dev/null; then \
		echo "Simulator is running (PID: `cat $(SIMULATOR_PID_FILE)`)"; \
		echo "Available at: http://localhost:5000/redfish/v1/"; \
		echo "Credentials: admin/pwd123456 or root/password123456 (for sessions)"; \
	else \
		echo "Simulator is not running"; \
	fi

.PHONY: test-simulator
test-simulator:
	@echo "Testing Redfish Profile Simulator endpoints..."
	@echo "1. Service Root:"
	@curl -s -u admin:pwd123456 http://localhost:5000/redfish/v1 | python3 -m json.tool | head -10 || echo "Failed to connect to simulator"
	@echo ""
	@echo "2. Systems Collection:"
	@curl -s -u admin:pwd123456 http://localhost:5000/redfish/v1/Systems | python3 -m json.tool | head -10 || echo "Failed to get Systems"
	@echo ""
	@echo "3. Sample System BIOS (first 5 attributes):"
	@curl -s -u admin:pwd123456 http://localhost:5000/redfish/v1/Systems/2M220100SL/Bios | python3 -c "import sys,json; data=json.load(sys.stdin); attrs=list(data['Attributes'].items())[:5]; print(json.dumps(dict(attrs), indent=2))" || echo "Failed to get BIOS settings"

# Build UEFI firmware
$(FIRMWARE_FILE): | setup-edk2 apply-templates $(KEY_FILES)
	@echo "Building UEFI firmware with Redfish early synchronization support..."
	export WORKSPACE=$(WORKSPACE) && \
	export PACKAGES_PATH="$(PACKAGES_PATH)" && \
	export GCC5_AARCH64_PREFIX="$(GCC5_AARCH64_PREFIX)" && \
	. edk2/edksetup.sh && \
	build -a $(ARCH) -t $(COMPILER) -b RELEASE \
		-p platforms/Platform/RaspberryPi/RPi4/RPi4.dsc \
		--pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"$(PROJECT_URL)" \
		--pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"UEFI Firmware $(VERSION)" \
		--pcd gEfiRedfishPkgTokenSpaceGuid.PcdRedfishHostName="10.0.198.24" \
		--pcd gEfiRedfishPkgTokenSpaceGuid.PcdRedfishServicePort=5000 \
		$(BUILD_FLAGS) $(DEFAULT_KEYS) $(TLS_DISABLE_FLAGS)

# Copy firmware to root directory
$(ARCHIVE_DIR)/RPI_EFI.fd: $(FIRMWARE_FILE)
	@echo "Copying firmware to root directory..."
	cp $(FIRMWARE_FILE) $(ARCHIVE_DIR)/RPI_EFI.fd

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
	cp -r $(ARCHIVE_DIR)/* /Volumes/BOOT/

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
clean: stop-simulator clean-platforms
	@echo "Cleaning build artifacts..."
	$(MAKE) -C $(IPXE_DIR) clean
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
	@echo "Redfish Simulator targets:"
	@echo "  setup-simulator    - Install Python dependencies for simulator"
	@echo "  start-simulator    - Start Redfish Profile Simulator"
	@echo "  stop-simulator     - Stop the running simulator"
	@echo "  simulator-status   - Check simulator running status"
	@echo "  test-simulator     - Test simulator endpoints and display sample data"
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
	@echo ""
	@echo "Redfish Testing Workflow:"
	@echo "  1. make start-simulator     # Start Redfish service"
	@echo "  2. make build              # Build firmware with Redfish support"
	@echo "  3. Boot RPi4 firmware      # Flash and boot the firmware"
	@echo "  4. Run RedfishPlatformConfig.efi from EFI Shell"
	@echo "  5. Reboot to test BIOS synchronization"

#!/bin/sh

set -e

# mkdir -p edk2/EmbeddedPkg/Drivers/IpxeDxe/AArch64
# cp "Drivers/IpxeDxe/IpxeDxe.inf" edk2/Drivers/IpxeDxe/IpxeDxe.inf
# install "ipxe/src/bin-arm64-efi/ipxe.efi" edk2/EmbeddedPkg/Drivers/IpxeDxe/AArch64/ipxe.efi

mkdir -p Drivers/IpxeDxe/AArch64 && install "ipxe/src/bin-arm64-efi/ipxe.efi" Drivers/IpxeDxe/AArch64/ipxe.efi

grep -qF -- "  Drivers/IpxeDxe/IpxeDxe.inf" edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '605i\  Drivers/IpxeDxe/IpxeDxe.inf' edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- "  INF Drivers/IpxeDxe/IpxeDxe.inf" "edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.fdf" || sed -i '248i\  INF Drivers/IpxeDxe/IpxeDxe.inf' edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.fdf
sed -i 's#gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB|L"RamMoreThan3GB"|gConfigDxeFormSetGuid|0x0|0#gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB|L"RamMoreThan3GB"|gConfigDxeFormSetGuid|0x0|1#g' edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
sed -i 's#gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB|L"RamLimitTo3GB"|gConfigDxeFormSetGuid|0x0|1#gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB|L"RamLimitTo3GB"|gConfigDxeFormSetGuid|0x0|0#g' edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- '                "*",' edk2/.pytool/CISettings.py || sed -i '75i\                "*",' edk2/.pytool/CISettings.py

make -C edk2/BaseTools

mkdir -p keys
# We don't really need a usable PK, so just generate a public key for it and discard the private key
openssl req -new -x509 -newkey rsa:2048 -subj "/CN=Raspberry Pi Platform Key/" -keyout /dev/null -outform DER -out keys/pk.cer -days 7300 -nodes -sha256
curl -L https://go.microsoft.com/fwlink/?LinkId=321185 -o keys/ms_kek1.cer
curl -L https://go.microsoft.com/fwlink/?linkid=2239775 -o keys/ms_kek2.cer
curl -L https://go.microsoft.com/fwlink/?linkid=321192 -o keys/ms_db1.cer
curl -L https://go.microsoft.com/fwlink/?linkid=321194 -o keys/ms_db2.cer
curl -L https://go.microsoft.com/fwlink/?linkid=2239776 -o keys/ms_db3.cer
curl -L https://go.microsoft.com/fwlink/?linkid=2239872 -o keys/ms_db4.cer
curl -L https://uefi.org/sites/default/files/resources/dbxupdate_arm64.bin -o keys/arm64_dbx.bin

export WORKSPACE=$PWD
export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi:$WORKSPACE
export BUILD_FLAGS="-D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE -D REDFISH_ENABLE=TRUE -D SECURE_BOOT_ENABLE=TRUE -D INCLUDE_TFTP_COMMAND=TRUE -D NETWORK_ISCSI_ENABLE=TRUE -D SMC_PCI_SUPPORT=1"
export TLS_DISABLE_FLAGS="-D NETWORK_TLS_ENABLE=FALSE -D NETWORK_ALLOW_HTTP_CONNECTIONS=TRUE"
export DEFAULT_KEYS="-D DEFAULT_KEYS=TRUE -D PK_DEFAULT_FILE=$WORKSPACE/keys/pk.cer -D KEK_DEFAULT_FILE1=$WORKSPACE/keys/ms_kek1.cer -D KEK_DEFAULT_FILE2=$WORKSPACE/keys/ms_kek2.cer -D DB_DEFAULT_FILE1=$WORKSPACE/keys/ms_db1.cer -D DB_DEFAULT_FILE2=$WORKSPACE/keys/ms_db2.cer -D DB_DEFAULT_FILE3=$WORKSPACE/keys/ms_db3.cer -D DB_DEFAULT_FILE4=$WORKSPACE/keys/ms_db4.cer -D DBX_DEFAULT_FILE1=$WORKSPACE/keys/arm64_dbx.bin"
export GCC5_AARCH64_PREFIX="aarch64-linux-gnu-"
# EDK2's 'build' command doesn't play nice with spaces in environmnent variables, so we can't move the PCDs there...
. edk2/edksetup.sh || exit $?

for BUILD_TYPE in DEBUG RELEASE; do
  build -a AARCH64 -t GCC5 -b $BUILD_TYPE -p edk2-platforms/Platform/RaspberryPi/RPi4/RPi4.dsc --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVendor=L"https://github.com/pftf/RPi4" --pcd gEfiMdeModulePkgTokenSpaceGuid.PcdFirmwareVersionString=L"UEFI Firmware v0.0.1" ${BUILD_FLAGS} ${DEFAULT_KEYS} ${TLS_DISABLE_FLAGS}
  TLS_DISABLE_FLAGS=""
done
cp Build/RPi4/RELEASE_GCC5/FV/RPI_EFI.fd .
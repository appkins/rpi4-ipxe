#!/usr/bin/env sh

grep -qF -- "!include RedfishPkg/RedfishComponents.dsc.inc" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '742a \!include RedfishPkg/RedfishComponents.dsc.inc' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc

grep -qF -- "  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '177a \  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- "  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib/PlatformHostInterfaceBmcUsbNicLib.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '177a \  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib/PlatformHostInterfaceBmcUsbNicLib.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc

grep -qF -- "  RedfishPlatformWantedDeviceLib|RedfishPkg/Library/RedfishPlatformWantedDeviceLibNull/RedfishPlatformWantedDeviceLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '169a \  RedfishPlatformWantedDeviceLib|RedfishPkg/Library/RedfishPlatformWantedDeviceLibNull/RedfishPlatformWantedDeviceLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- "  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceLibNull/PlatformHostInterfaceLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '169a \  RedfishPlatformHostInterfaceLib|RedfishPkg/Library/PlatformHostInterfaceLibNull/PlatformHostInterfaceLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- "  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '169a \  RedfishContentCodingLib|RedfishPkg/Library/RedfishContentCodingLibNull/RedfishContentCodingLibNull.inf' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc

grep -qF -- "!include RedfishPkg/RedfishLibs.dsc.inc" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '57a \!include RedfishPkg/RedfishLibs.dsc.inc' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- "  DEFINE REDFISH_CLIENT_ALL_AUTOGENED = TRUE" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '34a \  DEFINE REDFISH_ENABLE = TRUE' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
grep -qF -- "  DEFINE REDFISH_ENABLE          = TRUE" platforms/Platform/RaspberryPi/RPi4/RPi4.dsc || sed -i '34a \  DEFINE REDFISH_ENABLE          = TRUE' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc

grep -qF -- "!include RedfishPkg/Redfish.fdf.inc" "platforms/Platform/RaspberryPi/RPi4/RPi4.fdf" || sed -i '321a \!include RedfishPkg/Redfish.fdf.inc' platforms/Platform/RaspberryPi/RPi4/RPi4.fdf

sed -i 's#gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB|L"RamMoreThan3GB"|gConfigDxeFormSetGuid|0x0|0#gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB|L"RamMoreThan3GB"|gConfigDxeFormSetGuid|0x0|1#g' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc
sed -i 's#gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB|L"RamLimitTo3GB"|gConfigDxeFormSetGuid|0x0|1#gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB|L"RamLimitTo3GB"|gConfigDxeFormSetGuid|0x0|0#g' platforms/Platform/RaspberryPi/RPi4/RPi4.dsc

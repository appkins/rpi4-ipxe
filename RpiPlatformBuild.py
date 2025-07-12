##
## Script to Build Raspberry Pi 3/4 firmware
##
import os
import logging
from edk2toolext.environment.uefi_build import UefiBuilder
from edk2toolext.invocables.edk2_platform_build import BuildSettingsManager
from edk2toolext.invocables.edk2_setup import SetupSettingsManager
from edk2toolext.invocables.edk2_update import UpdateSettingsManager
from edk2toollib.utility_functions import GetHostInfo
from edk2toolext.invocables.edk2_setup import RequiredSubmodule

#
#==========================================================================
# PLATFORM BUILD ENVIRONMENT CONFIGURATION
#    
class RpiSettingsManager(UpdateSettingsManager, SetupSettingsManager, BuildSettingsManager):
    def __init__(self):
        SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))
        self.ws = SCRIPT_PATH

    def GetWorkspaceRoot(self):
        ''' get WorkspacePath '''
        return self.ws

    def GetActiveScopes(self):
        ''' get scope '''
        return ['raspberrypi', 'gcc_aarch64_linux']

    def GetPackagesPath(self):
        ''' get module packages path '''
        pp = ['edk2', "non-osi", 'platforms', 'redfish-client']
        ws = self.GetWorkspaceRoot()
        return [os.path.join(ws, x) for x in pp]

    def GetPackagesSupported(self):
        ''' return iterable of edk2 packages supported by this build.
        These should be edk2 workspace relative paths '''
        return ("RaspberryPi/RPi4", "RedfishClientPkg", )

    def GetRequiredSubmodules(self):
        ''' return iterable containing RequiredSubmodule objects.
        If no RequiredSubmodules return an empty iterable
        '''
        return [
            RequiredSubmodule("edk2"),
            RequiredSubmodule("non-osi"),
            RequiredSubmodule("platforms"),
            RequiredSubmodule("redfish-client"),
        ]

    def GetArchitecturesSupported(self):
        ''' return iterable of edk2 architectures supported by this build '''
        logging.info("Raspberry Pi 4 build supports AARCH64 architecture")
        return ("AARCH64")

    def GetTargetsSupported(self):
        ''' return iterable of edk2 target tags supported by this build '''
        return ("DEBUG", "RELEASE")

#--------------------------------------------------------------------------------------------------------
# Subclass the UEFI builder and add platform specific functionality.
# 
class PlatformBuilder(UefiBuilder):
    def SetPlatformEnv(self):
        self.env.SetValue("ACTIVE_PLATFORM", "Platform/RaspberryPi/RPi4/RPi4.dsc", "Platform Hardcoded")
        self.env.SetValue("PRODUCT_NAME", "RaspberryPi", "Platform Hardcoded")
        self.env.SetValue("TARGET_ARCH", "AARCH64", "Platform Hardcoded")
        # Not all variables are passed through stuart to the actual build command.
        # Only variables with the prefix BLD_*_, BLD_DEBUG_ and BLD_RELEASE_ are considered build values and consumed by the build command.
        self.env.SetValue("BLD_*_NETWORK_ALLOW_HTTP_CONNECTIONS", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_REDFISH_ENABLE", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_SECURE_BOOT_ENABLE", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_INCLUDE_TFTP_COMMAND", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_NETWORK_ISCSI_ENABLE", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_SMC_PCI_SUPPORT", "1", "Platform Hardcoded")
        os = GetHostInfo().os
        if os.lower() == "windows":
            self.env.SetValue("TOOL_CHAIN_TAG", "VS2017", "Platform Hardcoded", True)
        else:
            self.env.SetValue("TOOL_CHAIN_TAG", "GCC5", "Platform Hardcoded", True)

        return 0    

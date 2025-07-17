##
## Script to Build Raspberry Pi 3/4 firmware
##
import os
import logging
import re
from pathlib import Path
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
        SCRIPT_PATH = os.path.dirname(os.path.relpath(__file__))
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
        return ("Platform/RaspberryPi", "RedfishClientPkg")

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
    def __init__(self):
        UefiBuilder.__init__(self)
        self.profiles = {
            "DEV" : {"TARGET" : "DEBUG", "EDK_SHELL": ""},
            "SELFHOST" : {"TARGET" : "RELEASE", "EDK_SHELL": ""},
            "RELEASE" : {"TARGET" : "RELEASE"}
        }

    def GetWorkspaceRoot(self):
        ''' get WorkspacePath '''
        return os.path.dirname(os.path.abspath(__file__))

    def GetLoggingLevel(self):
        ''' Return the logging level '''
        return logging.INFO

    def GetLoggingFolderRelativeToRoot(self):
        ''' Return the logging folder relative to workspace root '''
        return "Build"

    def GetName(self):
        ''' Return the name of the platform '''
        return "RaspberryPi4"

    def GetPackagesPath(self):
        ''' get module packages path '''
        pp = ['edk2', "non-osi", 'platforms', 'redfish-client']
        ws = self.GetWorkspaceRoot()
        return [os.path.join(ws, x) for x in pp]

    def UpdateConf(self, filepath):
        ''' Override the default configuration update '''
        # This method is called by ConfMgmt to update template files
        # Return True to indicate successful update
        return False
    
    def GetConfTemplateFilePath(self):
        ''' Return the path to the template files directory '''
        # Return a list of paths where template files can be found
        workspace_root = self.GetWorkspaceRoot()
        return [os.path.join(workspace_root, "edk2", "BaseTools")]
    
    def SetPlatformEnv(self):
        # Set EDK_TOOLS_PATH to point to BaseTools directory
        workspace_root = self.GetWorkspaceRoot()
        edk_tools_path = os.path.join(workspace_root, "edk2", "BaseTools")
        self.env.SetValue("EDK_TOOLS_PATH", edk_tools_path, "Platform Hardcoded")
        
        # Add BaseTools to PATH
        basetools_bin_path = os.path.join(edk_tools_path, "BinWrappers", "PosixLike")
        current_path = self.env.GetValue("PATH")
        if current_path:
            new_path = f"{basetools_bin_path}:{current_path}"
        else:
            new_path = basetools_bin_path
        self.env.SetValue("PATH", new_path, "Platform Hardcoded")
        
        # Also set the PATH environment variable directly
        import os as system_os
        system_os.environ['PATH'] = new_path
        
        self.env.SetValue("ACTIVE_PLATFORM", "Platform/RaspberryPi/RPi4/RPi4.dsc", "Platform Hardcoded")
        self.env.SetValue("PRODUCT_NAME", "RaspberryPi", "Platform Hardcoded")
        self.env.SetValue("TARGET_ARCH", "AARCH64", "Platform Hardcoded")
        self.env.SetValue("PACKAGES_PATH", os.pathsep.join(self.GetPackagesPath()), "Platform Hardcoded")
        # Inject RedfishClient DSC includes before build
        # Temporarily commented out to test build without RedfishClient
        # self._inject_redfish_client_includes()
        
        # Not all variables are passed through stuart to the actual build command.
        # Only variables with the prefix BLD_*_, BLD_DEBUG_ and BLD_RELEASE_ are considered build values and consumed by the build command.
        self.env.SetValue("BLD_*_NETWORK_ALLOW_HTTP_CONNECTIONS", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_REDFISH_ENABLE", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_SECURE_BOOT_ENABLE", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_INCLUDE_TFTP_COMMAND", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_NETWORK_ISCSI_ENABLE", "TRUE", "Platform Hardcoded")
        self.env.SetValue("BLD_*_SMC_PCI_SUPPORT", "1", "Platform Hardcoded")
        host_os = GetHostInfo().os
        if host_os.lower() == "windows":
            self.env.SetValue("TOOL_CHAIN_TAG", "VS2017", "Platform Hardcoded", True)
        else:
            self.env.SetValue("TOOL_CHAIN_TAG", "GCC5", "Platform Hardcoded", True)

        return 0
    
    def _inject_redfish_client_includes(self):
        """Inject RedfishClient DSC includes into the platform DSC file."""
        try:            
            # Get the active platform DSC file path
            active_platform = self.env.GetValue("ACTIVE_PLATFORM")
            if not active_platform:
                logging.warning("No ACTIVE_PLATFORM defined, skipping RedfishClient injection")
                return
                
            # Find the DSC file in the platforms directory
            workspace_root = Path(self.GetWorkspaceRoot())
            dsc_file_path = workspace_root / "platforms" / active_platform
            
            if not dsc_file_path.exists():
                logging.error(f"Could not find DSC file: {dsc_file_path}")
                return
                
            logging.info(f"Processing DSC file: {dsc_file_path}")
            
            # Read the DSC file
            with open(dsc_file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Check if RedfishClient is already included
            if 'RedfishClientPkg/RedfishClientDefines.dsc.inc' in content:
                logging.info("RedfishClient already included in DSC file")
                return
                
            # Find the [Defines] section and inject RedfishClient includes
            defines_pattern = r'(\[Defines\][^\[]*)'
            defines_match = re.search(defines_pattern, content, re.MULTILINE | re.DOTALL)
            
            if not defines_match:
                logging.error("Could not find [Defines] section in DSC file")
                return
                
            # Insert the include after the [Defines] section header
            defines_section = defines_match.group(1)
            
            # Find a good insertion point (after existing includes or defines)
            lines = defines_section.split('\n')
            insert_index = 1  # After [Defines] line
            
            # Look for existing includes to insert near them
            for i, line in enumerate(lines):
                if '!include' in line.lower() or 'define ' in line:
                    insert_index = i + 1
                    
            # Insert the RedfishClient include
            lines.insert(insert_index, "  !include RedfishClientPkg/RedfishClientDefines.dsc.inc")
            
            # Reconstruct the defines section
            new_defines_section = '\n'.join(lines)
            
            # Replace the defines section in the content
            new_content = content.replace(defines_section, new_defines_section)
            
            # Also need to add the main RedfishClient.dsc.inc at the end of the file
            if 'RedfishClientPkg/RedfishClient.dsc.inc' not in new_content:
                # Add include at the end of file
                new_content += "\n\n# RedfishClient components, libraries, and PCDs\n"
                new_content += "!include RedfishClientPkg/RedfishClient.dsc.inc\n"
            
            # Write the modified content back
            with open(dsc_file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
                
            logging.info("Successfully injected RedfishClient includes into DSC file")
            
        except Exception as e:
            logging.error(f"Failed to inject RedfishClient includes: {e}")


if __name__ == "__main__":
    from edk2toolext.invocables.edk2_platform_build import Edk2PlatformBuild
    
    # Platform Settings Manager
    settingsManager = RpiSettingsManager()
    
    # Platform Builder
    platformBuilder = PlatformBuilder()
    
    # Build Invocable
    buildInvocable = Edk2PlatformBuild()
    buildInvocable.Invoke()

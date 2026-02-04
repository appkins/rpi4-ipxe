# PlatformBuild.py
import os
import sys
import logging
from edk2toolext.environment import shell_environment
from edk2toolext.environment.uefi_build import UefiBuilder
from edk2toolext.invocables.edk2_platform_build import BuildSettingsManager
from edk2toolext.invocables.edk2_setup import SetupSettingsManager, RequiredSubmodule
from edk2toolext.invocables.edk2_update import UpdateSettingsManager
from edk2toolext.invocables.edk2_pr_eval import PrEvalSettingsManager
from edk2toollib.utility_functions import RunCmd


# ####################################################################################### #
#                          Configuration Constants from Makefile                          #
# ####################################################################################### #

# Directory name constants
EDK2_DIR = "edk2"
PLATFORMS_DIR = "platforms"
NON_OSI_DIR = "non-osi"

# Build configuration from Makefile
BUILD_TYPE = "RELEASE"
ARCH = "AARCH64"
COMPILER = "GCC5"
GCC5_AARCH64_PREFIX = os.environ.get("GCC5_AARCH64_PREFIX", "aarch64-elf-")
PROJECT_URL = "https://github.com/pftf/RPi4"

# Build flags from Makefile
BUILD_FLAGS = {
    "NETWORK_ALLOW_HTTP_CONNECTIONS": "TRUE",
    "SECURE_BOOT_ENABLE": "TRUE",
    "INCLUDE_TFTP_COMMAND": "TRUE",
    "NETWORK_ISCSI_ENABLE": "TRUE",
    "SMC_PCI_SUPPORT": "1",
}

# TLS disable flags
TLS_DISABLE_FLAGS = {
    "NETWORK_TLS_ENABLE": "FALSE",
    "NETWORK_ALLOW_HTTP_CONNECTIONS": "TRUE",
}

# Secure Boot default keys flags
DEFAULT_KEYS = {
    "DEFAULT_KEYS": "TRUE",
    "PK_DEFAULT_FILE": "$(WORKSPACE)/keys/pk.cer",
    "KEK_DEFAULT_FILE1": "$(WORKSPACE)/keys/ms_kek1.cer",
    "KEK_DEFAULT_FILE2": "$(WORKSPACE)/keys/ms_kek2.cer",
    "DB_DEFAULT_FILE1": "$(WORKSPACE)/keys/ms_db1.cer",
    "DB_DEFAULT_FILE2": "$(WORKSPACE)/keys/ms_db2.cer",
    "DB_DEFAULT_FILE3": "$(WORKSPACE)/keys/ms_db3.cer",
    "DB_DEFAULT_FILE4": "$(WORKSPACE)/keys/ms_db4.cer",
    "DBX_DEFAULT_FILE1": "$(WORKSPACE)/keys/arm64_dbx.bin",
}

# Raspberry Pi platform-specific PCDs
RPI_PCDS = {
    "gRaspberryPiTokenSpaceGuid.PcdRamMoreThan3GB": "1",
    "gRaspberryPiTokenSpaceGuid.PcdRamLimitTo3GB": "0",
    "gEfiMdeModulePkgTokenSpaceGuid.PcdBootDiscoveryPolicy": "2",
    "gRaspberryPiTokenSpaceGuid.PcdSystemTableMode": "1",
    "gRaspberryPiTokenSpaceGuid.PcdXhciPci": "0",
    "gRaspberryPiTokenSpaceGuid.PcdXhciReload": "1",
}


# ####################################################################################### #
#                                Common Configuration                                     #
# ####################################################################################### #


class CommonPlatform():
    """Common settings for this platform. Define static data here and use for
    the different parts of stuart."""
    PackagesSupported = ("RPi4",)
    ArchSupported = (ARCH,)
    TargetsSupported = (BUILD_TYPE,)
    Scopes = ("rpi4", "gcc_aarch64")
    WorkspaceRoot = os.path.realpath(os.path.dirname(os.path.abspath(__file__)))


# ####################################################################################### #
#                       Configuration for Update & Setup                                  #
# ####################################################################################### #


class SettingsManager(UpdateSettingsManager, SetupSettingsManager, PrEvalSettingsManager):
    """Manager for Update, Setup, and PR Evaluation settings."""

    def GetPackagesSupported(self):
        """Return iterable of edk2 packages supported by this build."""
        return CommonPlatform.PackagesSupported

    def GetArchitecturesSupported(self):
        """Return iterable of edk2 architectures supported by this build."""
        return CommonPlatform.ArchSupported

    def GetTargetsSupported(self):
        """Return iterable of edk2 target tags supported by this build."""
        return CommonPlatform.TargetsSupported

    def GetRequiredSubmodules(self):
        """Return iterable containing RequiredSubmodule objects."""
        return [
            RequiredSubmodule(path=EDK2_DIR, recursive=True),
            RequiredSubmodule(path=PLATFORMS_DIR, recursive=False),
            RequiredSubmodule(path=NON_OSI_DIR, recursive=False),
        ]

    def SetArchitectures(self, list_of_requested_architectures):
        """Confirm the requested architecture list is valid and configure SettingsManager."""
        unsupported = set(list_of_requested_architectures) - set(self.GetArchitecturesSupported())
        if len(unsupported) > 0:
            logging.critical("Unsupported architectures requested: {}".format(unsupported))
            raise Exception("Unsupported architectures: {}".format(unsupported))
        self.ActualArchitectures = list_of_requested_architectures

    def GetWorkspaceRoot(self):
        """Get WorkspacePath."""
        return CommonPlatform.WorkspaceRoot

    def GetActiveScopes(self):
        """Return tuple containing scopes that should be active for this process."""
        return CommonPlatform.Scopes

    def FilterPackagesToTest(self, changedFilesList: list, potentialPackagesList: list) -> list:
        """Filter packages to test based on changed files."""
        build_these_packages = []
        possible_packages = potentialPackagesList.copy()
        for f in changedFilesList:
            if PLATFORMS_DIR in f:
                build_these_packages.extend(possible_packages)
                break
        return build_these_packages

    def GetPlatformDscAndConfig(self) -> tuple:
        """Return the platform DSC file path and configuration."""
        dsc_path = os.path.join(PLATFORMS_DIR, "Platform/RaspberryPi/RPi4/RPi4.dsc")
        return (dsc_path, {})

    def DoPostUpdate(self):
        """Apply patches after updating submodules."""
        logging.info("--- Starting Post-Update Patching ---")

        patch_dir = os.path.join(self.GetWorkspaceRoot(), "Patches")
        target_repo = os.path.join(self.GetWorkspaceRoot(), PLATFORMS_DIR)

        if not os.path.isdir(patch_dir):
            logging.info("No 'Patches' directory found. Skipping.")
            return True

        patches = sorted([p for p in os.listdir(patch_dir) if p.endswith((".patch", ".diff"))])

        if not patches:
            logging.info("No patch files found in 'Patches' folder.")
            return True

        for patch in patches:
            patch_path = os.path.abspath(os.path.join(patch_dir, patch))
            logging.info(f"Checking patch: {patch}")

            check_cmd = RunCmd("patch", f"-p1 < {patch_path}", workingdir=target_repo)

            if check_cmd == 0:
                logging.info(f"Applying {patch}...")
                if RunCmd("patch", f"-p1 < {patch_path}", workingdir=target_repo) != 0:
                    logging.error(f"Failed to apply {patch}")
                    return False
            else:
                logging.warning(f"Patch {patch} cannot be applied clean (may already be applied). Skipping.")

        return True


# ####################################################################################### #
#                      Actual Configuration for Platform Build                            #
# ####################################################################################### #


class PlatformBuilder(UefiBuilder, BuildSettingsManager):
    """Platform builder for Raspberry Pi 4 UEFI firmware."""

    def __init__(self):
        UefiBuilder.__init__(self)
        self.args = None

    def AddCommandLineOptions(self, parserObj):
        """Add command line options to the argument parser."""
        parserObj.add_argument("-a", "--arch", dest="build_arch", type=str, action="append",
                               choices=CommonPlatform.ArchSupported,
                               help="Specify architecture to build")

    def RetrieveCommandLineOptions(self, args):
        """Retrieve and process command line options."""
        self.args = args

        # Set build variables in shell environment
        shell_environment.GetBuildVars().SetValue(
            "TARGET_ARCH", ARCH, "Platform")
        shell_environment.GetBuildVars().SetValue(
            "TOOL_CHAIN_TAG", COMPILER, "Platform")

        # Set PACKAGES_PATH environment variable
        packages_path = ":".join(self.GetPackagesPath())
        shell_environment.GetBuildVars().SetValue(
            "PACKAGES_PATH", packages_path, "Platform")

        if hasattr(self.args, 'build_arch') and self.args.build_arch:
            self.SetArchitectures(self.args.build_arch)
        else:
            self.SetArchitectures(CommonPlatform.ArchSupported)

    def GetWorkspaceRoot(self):
        """Get workspace root directory."""
        return CommonPlatform.WorkspaceRoot

    def GetPackagesPath(self):
        """Get the packages path for the build (workspace-relative paths)."""
        return [
            EDK2_DIR,
            PLATFORMS_DIR,
            NON_OSI_DIR,
            "."
        ]

    def GetActiveScopes(self):
        """Return scopes active for this build."""
        return CommonPlatform.Scopes

    def GetName(self):
        """Get the platform name."""
        return "RPi4_UEFI"

    def GetLoggingLevel(self, loggerType):
        """Get logging level."""
        return logging.INFO

    def GetPackagesSupported(self):
        """Return packages supported by this build."""
        return CommonPlatform.PackagesSupported

    def GetArchitecturesSupported(self):
        """Return architectures supported by this build."""
        return CommonPlatform.ArchSupported

    def GetTargetsSupported(self):
        """Return targets supported by this build."""
        return CommonPlatform.TargetsSupported

    def SetPlatformEnv(self):
        """Set up the platform environment variables."""
        logging.debug("RPi4 Platform Environment Setup")

        # Set product name
        self.env.SetValue("PRODUCT_NAME", "RPi4_UEFI", "Platform")

        # Set tool chain tag
        self.env.SetValue("TOOL_CHAIN_TAG", COMPILER, "Platform")

        # Set active platform DSC (relative to PACKAGES_PATH, in platforms package)
        self.env.SetValue("ACTIVE_PLATFORM", "Platform/RaspberryPi/RPi4/RPi4.dsc", "Platform")

        # Set GCC5 prefix if needed
        if COMPILER == "GCC5":
            self.env.SetValue("GCC5_AARCH64_PREFIX", GCC5_AARCH64_PREFIX, "Platform")

        # Build target architecture
        self.env.SetValue("BLD_*_BUILD_ARCH", ARCH, "Platform")

        # Add edk2 build tools to PATH both in self.env and os.environ
        edk2_bin_path = os.path.join(self.GetWorkspaceRoot(), "edk2/BaseTools/BinWrappers/PosixLike")
        path_env = os.environ.get("PATH", "")
        if edk2_bin_path not in path_env:
            new_path = edk2_bin_path + ":" + path_env
            os.environ["PATH"] = new_path
            self.env.SetValue("PATH", new_path, "Platform")

        logging.debug(f"Platform configured: RPi4_UEFI with {COMPILER} for {ARCH}")
        return 0

    def PlatformPreBuild(self):
        """Perform pre-build platform configuration."""
        logging.debug("RPi4 Platform Pre-Build Configuration")
        return 0

    def PlatformPostBuild(self):
        """Perform post-build platform cleanup/finalization."""
        logging.debug("RPi4 Platform Post-Build Cleanup")
        return 0

    def GetArchitectures(self):
        """Get the build architectures."""
        return CommonPlatform.ArchSupported

    def GetTargets(self):
        """Get the build targets."""
        return CommonPlatform.TargetsSupported

    def GetToolChainTag(self, target):
        """Get the tool chain tag for the specified target."""
        return COMPILER

    def GetDscPath(self):
        """Get the platform DSC file path."""
        return os.path.join(PLATFORMS_DIR, "Platform/RaspberryPi/RPi4/RPi4.dsc")

    def SetArchitectures(self, list_of_requested_architectures):
        """Set architectures for this build."""
        unsupported = set(list_of_requested_architectures) - set(self.GetArchitectures())
        if len(unsupported) > 0:
            logging.critical("Unsupported architectures requested: {}".format(unsupported))
            raise Exception("Unsupported architectures: {}".format(unsupported))
        self.ActualArchitectures = list_of_requested_architectures


if __name__ == '__main__':
    import edk2toolext.invocables.edk2_platform_build as epb
    epb.main()

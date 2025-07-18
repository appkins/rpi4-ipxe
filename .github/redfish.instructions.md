The build compiles the firmware but does not produce the expected result. Upon adding the `RedfishPlatformConfig.efi` to the firmware image (.zip), I was able to run the application from the Raspberry Pi's UEFI shell. The efi program worked properly and set the intended EFI vars.

After rebooting, nothing changed. The firmware proceeded to boot the same as it did before making any changes. I suspect that we need to further modify the platform build and include the necessary components as DXE,

Compare the two platform `*.dec` files:

* edk2/EmulatorPkg/EmulatorPkg.dec
* platforms/Platform/RaspberryPi/RaspberryPi.dec

We want the behavior from `EmulatorPkg` where it syncs its state with the remote Redfish Service before boot.

Next compare:

* edk2/EmulatorPkg/EmulatorPkg.dsc
* platforms/Platform/RaspberryPi/RPi4/RPi4.dsc

and

* edk2/EmulatorPkg/EmulatorPkg.fdf
* platforms/Platform/RaspberryPi/RPi4/RPi4.fdf

---

Identify the components, drivers, etc that are responsible for the remote Redfish sync in the EmulatorPkg and reproduce the pattern in `templates/Platform/RaspberryPi`. Update the Makefile to remove the replacement code that alters the submodule files. Instead, alter the files under templates and overlay them onto the patching path at `platforms` during the build.

Lastly, use the redfish-simulator from `redfish-client/Tools/Redfish-Profile-Simulator` and completely replace the `testing` code. Simply add the build to the makefile and `.PHONY` targets to run the simulator. Add all documentation to `docs`.

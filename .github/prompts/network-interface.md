Review the device path traversal in `edk2/RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib`. Create a new `RedfishPlatformHostInterfaceLib` under `templates/Platform/RaspberryPi/Library`. Instead of `EFI_USB_IO_PROTOCOL`, we'll be using `EFI_PCI_IO_PROTOCOL` from `ipxe/src/include/ipxe/efi/Protocol/PciIo.h`.

To facilitate this change, we will use the struct `PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2`, replacing `USB_INTERFACE_DEVICE_DESCRIPTOR_V2` from `edk2/RedfishPkg/Include/IndustryStandard/RedfishHostInterface.h`. Instances that reference `UsbDeviceV2` like `DeviceDescriptor.UsbDeviceV2` should instead use `PciPcieDeviceV2` i.e `DeviceDescriptor.PciPcieDeviceV2`.

This implementation will be entirely out of band, leveraging the Raspberry PI's on board NIC. We do not want to include anything related to In band access like IPMI etc.

Keep the library simple, while following the patterns in `edk2/RedfishPkg/Library/PlatformHostInterfaceBmcUsbNicLib`.

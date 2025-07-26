/** @file
  Header file to provide the platform Redfish Host Interface information
  for Raspberry Pi on-board PCI NIC Device.

  Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
  Copyright (c) 2025, Raspberry Pi Foundation. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#ifndef REDFISH_PLATFORM_HOST_INTERFACE_LIB_H_
#define REDFISH_PLATFORM_HOST_INTERFACE_LIB_H_

#include <Uefi.h>
#include <IndustryStandard/RedfishHostInterfaceIpmi.h>
#include <IndustryStandard/SmBios.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/DevicePathLib.h>
#include <Library/RedfishHostInterfaceLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/DevicePathLib.h>
#include <Library/RedfishDebugLib.h>

#include <Protocol/EdkIIRedfishCredential2.h>
#include <Protocol/SimpleNetwork.h>

//
// Use the standard EFI PCI IO Protocol
//
#include <Protocol/PciIo.h>

#define RPI_PCI_NIC_HOST_INTERFACE_READINESS_GUID \
    {  \
      0x11A2F5D7, 0x4AE1, 0x4E6C, {0xA1, 0x30, 0xA5, 0xAC, 0x77, 0xDD, 0xE4, 0xA5} \
    }

//
// Define PCI interface device descriptor V2 size based on the standard structure
// from edk2/RedfishPkg/Include/IndustryStandard/RedfishHostInterface.h
// PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2 structure size is 19 bytes
//
#define PCI_INTERFACE_DEVICE_DESCRIPTOR_V2_SIZE  0x13  // 19 bytes

//
// Remove the extended structure as we should use the standard one from RedfishHostInterface.h
// The standard PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2 is sufficient
//

//
// This is the structure for Raspberry Pi on-board
// PCI NIC information.
//
typedef struct {
  LIST_ENTRY                     NextInstance;              ///< Link to the next instance.
  BOOLEAN                        IsOnBoardNic;              ///< Flag indicates this is the on-board PCI NIC.
  BOOLEAN                        IsSupportedHostInterface;  ///< This PCI NIC is supported
                                                            ///< as Redfish host interface
  EFI_SIMPLE_NETWORK_PROTOCOL    *ThisSnp;                  ///< The SNP instance associated with
                                                            ///< this PCI NIC.
  EFI_PCI_IO_PROTOCOL            *ThisPciIo;                ///< The PCI IO instance associated with
                                                            ///< this PCI NIC.
  UINT16                         PciVendorId;               ///< PCI Vendor ID of this NIC.
  UINT16                         PciDeviceId;               ///< PCI Device ID of this NIC.
  UINT16                         PciSubsystemVendorId;      ///< PCI Subsystem Vendor ID.
  UINT16                         PciSubsystemId;            ///< PCI Subsystem ID.
  UINT16                         PciSegmentNumber;          ///< PCI Segment Number.
  UINT8                          PciBusNumber;              ///< PCI Bus Number.
  UINT8                          PciDeviceFunctionNumber;   ///< PCI Device/Function Number.
  UINTN                          MacAddressSize;            ///< HW address size.
  UINT8                          *MacAddress;               ///< HW address.

  //
  // Below is the information for building SMBIOS type 42.
  //
  UINT8                          IpAssignedType;          ///< Redfish service IP assign type.
  UINT8                          IpAddressFormat;         ///< Redfish service IP version.
  UINT8                          HostIpAddressIpv4[4];    ///< Host IP address.
  UINT8                          RedfishIpAddressIpv4[4]; ///< Redfish service IP address.
  UINT8                          SubnetMaskIpv4[4];       ///< Subnet mask.
  UINT8                          GatewayIpv4[4];          ///< Gateway IP address.
  UINT16                         VLanId;                  ///< VLAN ID.
  BOOLEAN                        CredentialBootstrapping; ///< If Credential bootstrapping is
                                                          ///< supported.
} HOST_INTERFACE_RPI_PCI_NIC_INFO;

#endif

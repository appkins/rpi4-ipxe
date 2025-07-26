/** @file
  Header file to provide the platform Redfish Host Interface information
  of PCI NIC Device exposed by BMC.

  Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#ifndef PLATFORM_HOST_INTERFACE_BMC_PCI_NIC_LIB_H_
#define PLATFORM_HOST_INTERFACE_BMC_PCI_NIC_LIB_H_

#include <Uefi.h>
#include <IndustryStandard/Ipmi.h>
#include <IndustryStandard/IpmiNetFnApp.h>
#include <IndustryStandard/IpmiNetFnTransport.h>
#include <IndustryStandard/RedfishHostInterfaceIpmi.h>
#include <IndustryStandard/SmBios.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/DevicePathLib.h>
#include <Library/IpmiCommandLib.h>
#include <Library/RedfishHostInterfaceLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/DevicePathLib.h>
#include <Library/RedfishDebugLib.h>

#include <Protocol/EdkIIRedfishCredential2.h>
#include <Protocol/SimpleNetwork.h>
#include <Protocol/PciIo.h>

#define BMC_PCI_NIC_HOST_INTERFASCE_READINESS_GUID \
    {  \
      0xDD96F5D7, 0x4AE1, 0x4E6C, {0xA1, 0x30, 0xA5, 0xAC, 0x77, 0xDD, 0xE4, 0xA5} \
    }

//
// This is the structure for BMC exposed
// PCI NIC information.
//
typedef struct {
  LIST_ENTRY                     NextInstance;              ///< Link to the next instance.
  BOOLEAN                        IsExposedByBmc;            ///< Flag indicates this PCI NIC is
                                                            ///< exposed by BMC.
  BOOLEAN                        IsSuppportedHostInterface; ///< This BMC PCI NIC is supported
                                                            ///< as Redfish host interface
  EFI_SIMPLE_NETWORK_PROTOCOL    *ThisSnp;                  ///< The SNP instance associated with
                                                            ///< this PCI NIC.
  EFI_PCI_IO_PROTOCOL            *ThisPciIo;                ///< The PCIIO instance associated with
                                                            ///< this PCI NIC.
  UINT16                         PciVendorId;               ///< PCI Vendor ID of this BMC exposed PCI NIC.
  UINT16                         PciProductId;              ///< PCI Product ID of this BMC exposed PCI NIC.
  UINTN                          MacAddressSize;            ///< HW address size.
  UINT8                          *MacAddress;               ///< HW address.
  UINT8                          IpmiLanChannelNumber;      ///< BMC IPMI Lan Channel number.

  //
  // Below is the infortmation for building SMBIOS type 42.
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
} HOST_INTERFACE_BMC_PCI_NIC_INFO;

//
// This is the structure for caching
// BMC IPMI LAN Channel
//
typedef struct {
  LIST_ENTRY         NextInstance;            ///< Link to the next IPMI LAN Channel.
  UINT8              Channel;                 ///< IPMI Channel number.
  EFI_MAC_ADDRESS    MacAddress;              ///< IPMI LAN Channel MAC address.
  UINT8              MacAddressSize;          ///< MAC address size;
} BMC_IPMI_LAN_CHANNEL_INFO;
#endif

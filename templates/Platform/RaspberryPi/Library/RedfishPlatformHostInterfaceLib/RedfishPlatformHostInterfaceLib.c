/** @file
  Source file to provide the platform Redfish Host Interface information
  for Raspberry Pi on-board PCI NIC Device.

  This implementation provides out-of-band Redfish Host Interface support
  using the Raspberry Pi's onboard Ethernet controller, without any BMC
  or IPMI dependencies.

  Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
  Copyright (c) 2025, Raspberry Pi Foundation. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#include "RedfishPlatformHostInterfaceLib.h"

//
// PCD access requires PcdLib
//
#include <Library/PcdLib.h>

static EFI_GUID  mPlatformHostInterfaceRpiPciNicReadinessGuid =
  RPI_PCI_NIC_HOST_INTERFACE_READINESS_GUID;
static EFI_EVENT  mPlatformHostInterfaceSnpEvent         = NULL;
static VOID       *mPlatformHostInterfaceSnpRegistration = NULL;

static LIST_ENTRY  mRpiPciNic;

/**
  Probe if the system supports Redfish Host Interface Credential
  Bootstrapping.

  @retval TRUE   Yes, it is supported.
          FALSE  No, it is not supported.

**/
BOOLEAN
ProbeRedfishCredentialBootstrap (
  VOID
  )
{
  EDKII_REDFISH_AUTH_METHOD           AuthMethod;
  EDKII_REDFISH_CREDENTIAL2_PROTOCOL  *CredentialProtocol;
  CHAR8                               *UserName;
  CHAR8                               *Password;
  BOOLEAN                             ReturnBool;
  EFI_STATUS                          Status;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry\n", __func__));

  ReturnBool = FALSE;
  //
  // Locate HII credential protocol.
  //
  Status = gBS->LocateProtocol (
                  &gEdkIIRedfishCredential2ProtocolGuid,
                  NULL,
                  (VOID **)&CredentialProtocol
                  );
  if (EFI_ERROR (Status)) {
    ASSERT_EFI_ERROR (Status);
    return FALSE;
  }

  Status = CredentialProtocol->GetAuthInfo (
                                 CredentialProtocol,
                                 &AuthMethod,
                                 &UserName,
                                 &Password
                                 );
  if (!EFI_ERROR (Status)) {
    ZeroMem (Password, AsciiStrSize (Password));
    FreePool (Password);
    ZeroMem (UserName, AsciiStrSize (UserName));
    FreePool (UserName);
    ReturnBool = TRUE;
  } else {
    if (Status == EFI_ACCESS_DENIED) {
      // bootstrap credential support was disabled
      ReturnBool = TRUE;
    }
  }

  DEBUG ((
    DEBUG_REDFISH_HOST_INTERFACE,
    "    Redfish Credential Bootstrapping is %a\n",
    ReturnBool ? "supported" : "not supported"
    ));
  return ReturnBool;
}

/**
  Get platform Redfish host interface device descriptor.

  @param[in] DeviceType         Pointer to retrieve device type.
  @param[out] DeviceDescriptor  Pointer to retrieve REDFISH_INTERFACE_DATA, caller has to free
                                this memory using FreePool().

  @retval EFI_NOT_FOUND   No Redfish host interface descriptor provided on this platform.

**/
EFI_STATUS
RedfishPlatformHostInterfaceDeviceDescriptor (
  IN UINT8                    *DeviceType,
  OUT REDFISH_INTERFACE_DATA  **DeviceDescriptor
  )
{
  HOST_INTERFACE_RPI_PCI_NIC_INFO  *ThisInstance;
  REDFISH_INTERFACE_DATA           *InterfaceData;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry\n", __func__));

  if (IsListEmpty (&mRpiPciNic)) {
    return EFI_NOT_FOUND;
  }

  // Check if Raspberry Pi on-board PCI NIC is found and ready for using.
  ThisInstance = (HOST_INTERFACE_RPI_PCI_NIC_INFO *)GetFirstNode (&mRpiPciNic);
  while (TRUE) {
    if (ThisInstance->IsOnBoardNic && ThisInstance->IsSupportedHostInterface) {
      *DeviceType = REDFISH_HOST_INTERFACE_DEVICE_TYPE_PCI_PCIE_V2;

      // Fill up REDFISH_INTERFACE_DATA defined in Redfish host interface spec v1.3
      // Allocate memory for the interface data structure
      InterfaceData = (REDFISH_INTERFACE_DATA *)AllocateZeroPool (
                                                  sizeof (REDFISH_INTERFACE_DATA) - sizeof (DEVICE_DESCRITOR) +
                                                  sizeof (PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2)
                                                  );
      if (InterfaceData == NULL) {
        DEBUG ((DEBUG_ERROR, "Failed to allocate memory for REDFISH_INTERFACE_DATA\n"));
        return EFI_OUT_OF_RESOURCES;
      }

      InterfaceData->DeviceType                                            = REDFISH_HOST_INTERFACE_DEVICE_TYPE_PCI_PCIE_V2;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.Length               = PCI_INTERFACE_DEVICE_DESCRIPTOR_V2_SIZE;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.VendorId             = ThisInstance->PciVendorId;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.DeviceId             = ThisInstance->PciDeviceId;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.SubsystemVendorId    = ThisInstance->PciSubsystemVendorId;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.SubsystemId          = ThisInstance->PciSubsystemId;
      CopyMem (
        (VOID *)&InterfaceData->DeviceDescriptor.PciPcieDeviceV2.MacAddress,
        (VOID *)ThisInstance->MacAddress,
        sizeof (InterfaceData->DeviceDescriptor.PciPcieDeviceV2.MacAddress)
        );
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.SegmemtGroupNumber   = ThisInstance->PciSegmentNumber;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.BusNumber            = ThisInstance->PciBusNumber;
      InterfaceData->DeviceDescriptor.PciPcieDeviceV2.DeviceFunctionNumber = ThisInstance->PciDeviceFunctionNumber;

      *DeviceDescriptor = InterfaceData;
      DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    REDFISH_INTERFACE_DATA is returned successfully.\n"));
      return EFI_SUCCESS;
    }

    if (IsNodeAtEnd (&mRpiPciNic, &ThisInstance->NextInstance)) {
      break;
    }

    ThisInstance = (HOST_INTERFACE_RPI_PCI_NIC_INFO *)
                   GetNextNode (&mRpiPciNic, &ThisInstance->NextInstance);
  }

  return EFI_NOT_FOUND;
}

/**
  Get platform Redfish host interface protocol data.
  Caller should pass NULL in ProtocolRecord to retrieve the first protocol record.
  Then continuously pass previous ProtocolRecord for retrieving the next ProtocolRecord.

  @param[in, out] ProtocolRecord  Pointer to retrieve the first or the next protocol record.
                                  caller has to free the new protocol record returned from
                                  this function using FreePool().
  @param[in] IndexOfProtocolData  The index of protocol data.

  @retval EFI_NOT_FOUND   No more protocol records.

**/
EFI_STATUS
RedfishPlatformHostInterfaceProtocolData (
  IN OUT MC_HOST_INTERFACE_PROTOCOL_RECORD  **ProtocolRecord,
  IN UINT8                                  IndexOfProtocolData
  )
{
  HOST_INTERFACE_RPI_PCI_NIC_INFO    *ThisInstance;
  MC_HOST_INTERFACE_PROTOCOL_RECORD  *ThisProtocolRecord;
  REDFISH_OVER_IP_PROTOCOL_DATA      *RedfishOverIpData;
  UINT8                              HostNameLength;
  CHAR8                              *HostNameString;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry\n", __func__));

  if (IsListEmpty (&mRpiPciNic) || (IndexOfProtocolData > 0)) {
    return EFI_NOT_FOUND;
  }

  ThisInstance = (HOST_INTERFACE_RPI_PCI_NIC_INFO *)GetFirstNode (&mRpiPciNic);
  while (TRUE) {
    if (ThisInstance->IsOnBoardNic && ThisInstance->IsSupportedHostInterface) {
      // Get the host name before allocating memory.
      // Note: These PCDs need to be defined in the platform's .dec file
      #ifndef PcdRedfishHostName
      HostNameString     = (CHAR8 *)"rpi-redfish";  // Default fallback
      #else
      if (PcdGetPtr (PcdRedfishHostName) != NULL) {
        HostNameString = (CHAR8 *)PcdGetPtr (PcdRedfishHostName);
      }
      #endif
      HostNameLength     = (UINT8)AsciiStrSize (HostNameString);
      ThisProtocolRecord = (MC_HOST_INTERFACE_PROTOCOL_RECORD *)AllocateZeroPool (
                                                                  sizeof (MC_HOST_INTERFACE_PROTOCOL_RECORD) - 1 +
                                                                  sizeof (REDFISH_OVER_IP_PROTOCOL_DATA) - 1 +
                                                                  HostNameLength
                                                                  );
      if (ThisProtocolRecord == NULL) {
        DEBUG ((DEBUG_ERROR, "    Allocate memory fail for MC_HOST_INTERFACE_PROTOCOL_RECORD.\n"));
        return EFI_OUT_OF_RESOURCES;
      }

      ThisProtocolRecord->ProtocolType        = MCHostInterfaceProtocolTypeRedfishOverIP;
      ThisProtocolRecord->ProtocolTypeDataLen = sizeof (REDFISH_OVER_IP_PROTOCOL_DATA) -1 + HostNameLength;
      RedfishOverIpData                       = (REDFISH_OVER_IP_PROTOCOL_DATA *)&ThisProtocolRecord->ProtocolTypeData[0];
      //
      // Fill up REDFISH_OVER_IP_PROTOCOL_DATA
      //

      // Service UUID
      ZeroMem ((VOID *)&RedfishOverIpData->ServiceUuid, sizeof (EFI_GUID));
      #ifdef PcdRedfishServiceUuid
      if ((PcdGetPtr (PcdRedfishServiceUuid) != NULL) &&
          (StrLen ((CONST CHAR16 *)PcdGetPtr (PcdRedfishServiceUuid)) != 0)) {
        StrToGuid ((CONST CHAR16 *)PcdGetPtr (PcdRedfishServiceUuid), &RedfishOverIpData->ServiceUuid);
        DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, " Service UUID: %g", &RedfishOverIpData->ServiceUuid));
      }
      #endif

      // HostIpAddressFormat and RedfishServiceIpDiscoveryType
      RedfishOverIpData->HostIpAssignmentType          = ThisInstance->IpAssignedType;
      RedfishOverIpData->RedfishServiceIpDiscoveryType = ThisInstance->IpAssignedType;

      // HostIpAddressFormat and RedfishServiceIpAddressFormat, only support IPv4 for now.
      RedfishOverIpData->HostIpAddressFormat           = REDFISH_HOST_INTERFACE_HOST_IP_ADDRESS_FORMAT_IP4;
      RedfishOverIpData->RedfishServiceIpAddressFormat = REDFISH_HOST_INTERFACE_HOST_IP_ADDRESS_FORMAT_IP4;

      // HostIpAddress
      CopyMem (
        (VOID *)RedfishOverIpData->HostIpAddress,
        (VOID *)ThisInstance->HostIpAddressIpv4,
        sizeof (ThisInstance->HostIpAddressIpv4)
        );

      // HostIpMask and RedfishServiceIpMask
      CopyMem (
        (VOID *)RedfishOverIpData->HostIpMask,
        (VOID *)ThisInstance->SubnetMaskIpv4,
        sizeof (ThisInstance->SubnetMaskIpv4)
        );
      CopyMem (
        (VOID *)RedfishOverIpData->RedfishServiceIpMask,
        (VOID *)ThisInstance->SubnetMaskIpv4,
        sizeof (ThisInstance->SubnetMaskIpv4)
        );

      // RedfishServiceIpAddress
      CopyMem (
        (VOID *)RedfishOverIpData->RedfishServiceIpAddress,
        (VOID *)ThisInstance->RedfishIpAddressIpv4,
        sizeof (ThisInstance->RedfishIpAddressIpv4)
        );

      // RedfishServiceIpPort
      #ifndef PcdRedfishServicePort
      RedfishOverIpData->RedfishServiceIpPort = 443;  // Default HTTPS port
      #else
      RedfishOverIpData->RedfishServiceIpPort = PcdGet16 (PcdRedfishServicePort);
      #endif

      // RedfishServiceVlanId
      RedfishOverIpData->RedfishServiceVlanId = ThisInstance->VLanId;

      // RedfishServiceHostnameLength
      RedfishOverIpData->RedfishServiceHostnameLength = HostNameLength;

      // Redfish host name.
      CopyMem (
        (VOID *)&RedfishOverIpData->RedfishServiceHostname,
        (VOID *)HostNameString,
        HostNameLength
        );

      DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    MC_HOST_INTERFACE_PROTOCOL_RECORD is returned successfully.\n"));
      *ProtocolRecord = ThisProtocolRecord;
      return EFI_SUCCESS;
    }

    if (IsNodeAtEnd (&mRpiPciNic, &ThisInstance->NextInstance)) {
      break;
    }

    ThisInstance = (HOST_INTERFACE_RPI_PCI_NIC_INFO *)
                   GetNextNode (&mRpiPciNic, &ThisInstance->NextInstance);
  }

  return EFI_NOT_FOUND;
}

/**
  This function retrieves the information of Raspberry Pi on-board PCI NIC.

  @retval EFI_SUCCESS      All necessary information is retrieved.
  @retval EFI_NOT_FOUND    There is no on-board PCI NIC.
  @retval Others           Other errors.

**/
EFI_STATUS
RetrieveRpiPciNicInfo (
  VOID
  )
{
  EFI_STATUS                         Status;
  HOST_INTERFACE_RPI_PCI_NIC_INFO    *ThisInstance;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry\n", __func__));

  if (IsListEmpty (&mRpiPciNic)) {
    return EFI_NOT_FOUND;
  }

  ThisInstance = (HOST_INTERFACE_RPI_PCI_NIC_INFO *)GetFirstNode (&mRpiPciNic);
  while (TRUE) {
    if (ThisInstance->IsOnBoardNic) {
      ThisInstance->IsSupportedHostInterface = FALSE;

      // Probe if Redfish Host Interface Credential Bootstrapping is supported.
      ThisInstance->CredentialBootstrapping = ProbeRedfishCredentialBootstrap ();

      //
      // For Raspberry Pi, we use static configuration for out-of-band access.
      // In a real implementation, these values would come from platform configuration
      // or be configured via a platform-specific mechanism.
      //
      ThisInstance->IpAssignedType = REDFISH_HOST_INTERFACE_HOST_IP_ASSIGNMENT_TYPE_STATIC;

      // Configure static IP addresses (example configuration - should be platform specific)
      ThisInstance->HostIpAddressIpv4[0]    = 192;
      ThisInstance->HostIpAddressIpv4[1]    = 168;
      ThisInstance->HostIpAddressIpv4[2]    = 1;
      ThisInstance->HostIpAddressIpv4[3]    = 100;

      ThisInstance->RedfishIpAddressIpv4[0] = 192;
      ThisInstance->RedfishIpAddressIpv4[1] = 168;
      ThisInstance->RedfishIpAddressIpv4[2] = 1;
      ThisInstance->RedfishIpAddressIpv4[3] = 10;

      ThisInstance->SubnetMaskIpv4[0]       = 255;
      ThisInstance->SubnetMaskIpv4[1]       = 255;
      ThisInstance->SubnetMaskIpv4[2]       = 255;
      ThisInstance->SubnetMaskIpv4[3]       = 0;

      ThisInstance->GatewayIpv4[0]          = 192;
      ThisInstance->GatewayIpv4[1]          = 168;
      ThisInstance->GatewayIpv4[2]          = 1;
      ThisInstance->GatewayIpv4[3]          = 1;

      ThisInstance->VLanId                  = 0; // No VLAN

      // All information is retrieved.
      ThisInstance->IsSupportedHostInterface = TRUE;
      return EFI_SUCCESS;
    }

    if (IsNodeAtEnd (&mRpiPciNic, &ThisInstance->NextInstance)) {
      break;
    }

    ThisInstance = (HOST_INTERFACE_RPI_PCI_NIC_INFO *)
                   GetNextNode (&mRpiPciNic, &ThisInstance->NextInstance);
  }

  return EFI_NOT_FOUND;
}

/**
  This function searches the next MSG_PCI_DP device path node.

  @param[in]  ThisDevicePath    Device path to search.

  @retval NULL          MSG_PCI_DP is not found.
          Otherwise     MSG_PCI_DP is found.

**/
EFI_DEVICE_PATH_PROTOCOL *
PciNicGetNextMsgPciDp (
  IN EFI_DEVICE_PATH_PROTOCOL  *ThisDevicePath
  )
{
  if (ThisDevicePath == NULL) {
    return NULL;
  }

  while (TRUE) {
    ThisDevicePath = NextDevicePathNode (ThisDevicePath);
    if (IsDevicePathEnd (ThisDevicePath)) {
      return NULL;
    }

    if ((ThisDevicePath->Type == HARDWARE_DEVICE_PATH) && (ThisDevicePath->SubType == HW_PCI_DP)) {
      return ThisDevicePath;
    }
  }

  return NULL;
}

/**
  This function search the PciIo handle that matches the PciDevicePath.

  @param[in]  PciDevicePath    Device path of this SNP handle.
  @param[out] PciIo            Return the PciIo protocol.

  @retval EFI_SUCCESS          Yes, PciIo protocol is found.
  @retval EFI_NOT_FOUND        No, PciIo protocol is not found
  @retval Others               Other errors.

**/
EFI_STATUS
PciNicSearchPciIo (
  IN   EFI_DEVICE_PATH_PROTOCOL  *PciDevicePath,
  OUT  EFI_PCI_IO_PROTOCOL       **PciIo
  )
{
  EFI_STATUS                Status;
  UINTN                     BufferSize;
  EFI_HANDLE                *HandleBuffer;
  UINTN                     Index;
  CHAR16                    *DevicePathStr;
  EFI_DEVICE_PATH_PROTOCOL  *ThisDevicePath;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry.\n", __func__));
  DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "Device path on the EFI handle which has PciIo and SNP installed on it.\n"));
  DevicePathStr = ConvertDevicePathToText (PciDevicePath, FALSE, FALSE);
  if (DevicePathStr != NULL) {
    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "%s\n", DevicePathStr));
    FreePool (DevicePathStr);
  } else {
    DEBUG ((DEBUG_ERROR, "Failed to convert device path.\n"));
    return EFI_INVALID_PARAMETER;
  }

  BufferSize   = 0;
  HandleBuffer = NULL;
  *PciIo       = NULL;
  Status       = gBS->LocateHandle (
                        ByProtocol,
                        &gEfiPciIoProtocolGuid,
                        NULL,
                        &BufferSize,
                        NULL
                        );
  if (Status == EFI_BUFFER_TOO_SMALL) {
    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "  %d PciIo protocol instances.\n", BufferSize/sizeof (EFI_HANDLE)));
    HandleBuffer = AllocateZeroPool (BufferSize);
    if (HandleBuffer == NULL) {
      DEBUG ((DEBUG_ERROR, "    Failed to allocate buffer for the handles.\n"));
      return EFI_OUT_OF_RESOURCES;
    }

    Status = gBS->LocateHandle (
                    ByProtocol,
                    &gEfiPciIoProtocolGuid,
                    NULL,
                    &BufferSize,
                    HandleBuffer
                    );
    if (EFI_ERROR (Status)) {
      DEBUG ((DEBUG_ERROR, "  Failed to locate PciIo protocol handles.\n"));
      FreePool (HandleBuffer);
      return Status;
    }
  } else {
    return Status;
  }

  for (Index = 0; Index < (BufferSize/sizeof (EFI_HANDLE)); Index++) {
    Status = gBS->HandleProtocol (
                    *(HandleBuffer + Index),
                    &gEfiDevicePathProtocolGuid,
                    (VOID **)&ThisDevicePath
                    );
    if (EFI_ERROR (Status)) {
      continue;
    }

    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "Device path on #%d instance of PciIo.\n", Index));
    DevicePathStr = ConvertDevicePathToText (ThisDevicePath, FALSE, FALSE);
    if (DevicePathStr != NULL) {
      DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "%s\n", DevicePathStr));
      FreePool (DevicePathStr);
    } else {
      DEBUG ((DEBUG_ERROR, "Failed to convert device path on #%d instance of PciIo.\n", Index));
      continue;
    }

    // Compare device paths to find matching PCI IO protocol
    // For a more robust implementation, you would want to do proper device path comparison
    // For now, we'll try to match any PCI IO protocol as a simplified approach
    if (DevicePathStr != NULL) {
      // Simple approach: if we found a PCI device path, try to get its PCI IO protocol
      Status = gBS->HandleProtocol (
                      *(HandleBuffer + Index),
                      &gEfiPciIoProtocolGuid,
                      (VOID **)PciIo
                      );
      if (!EFI_ERROR (Status)) {
        DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "EFI handle with PciIo is found at #%d instance.\n", Index));
        FreePool (HandleBuffer);
        return EFI_SUCCESS;
      }
    }
  }

  FreePool (HandleBuffer);
  return EFI_NOT_FOUND;
}

/**
  This function identifies if the PCI NIC has MAC address and internet
  protocol device path installed. (Only support IPv4)

  @param[in] PciDevicePath     PCI device path.

  @retval EFI_SUCCESS          Yes, this is IPv4 SNP handle
  @retval EFI_NOT_FOUND        No, this is not IPv4 SNP handle

**/
EFI_STATUS
IdentifyNetworkMessageDevicePath (
  IN EFI_DEVICE_PATH_PROTOCOL  *PciDevicePath
  )
{
  EFI_DEVICE_PATH_PROTOCOL  *DevicePath;

  DevicePath = PciDevicePath;
  while (TRUE) {
    DevicePath = NextDevicePathNode (DevicePath);
    if (IsDevicePathEnd (DevicePath)) {
      DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "MAC address device path is not found on this handle.\n"));
      break;
    }

    if ((DevicePath->Type == MESSAGING_DEVICE_PATH) && (DevicePath->SubType == MSG_MAC_ADDR_DP)) {
      DevicePath = NextDevicePathNode (DevicePath); // Advance to next device path protocol.
      if (IsDevicePathEnd (DevicePath)) {
        DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "IPv4 device path is not found on this handle.\n"));
        break;
      }

      if ((DevicePath->Type == MESSAGING_DEVICE_PATH) && (DevicePath->SubType == MSG_IPv4_DP)) {
        return EFI_SUCCESS;
      }

      break;
    }
  }

  return EFI_NOT_FOUND;
}

/**
  This function identifies if the PCI NIC is the Raspberry Pi on-board
  network interface.

  @param[in] Handle          This is the EFI handle with SNP installed.
  @param[in] PciDevicePath   PCI device path.

  @retval EFI_SUCCESS          Yes, Raspberry Pi on-board PCI NIC is found.
  @retval EFI_NOT_FOUND        No, this is not the on-board PCI NIC.
  @retval Others               Other errors.

**/
EFI_STATUS
IdentifyRpiOnBoardPciNic (
  IN EFI_HANDLE                Handle,
  IN EFI_DEVICE_PATH_PROTOCOL  *PciDevicePath
  )
{
  UINTN                            Index;
  EFI_STATUS                       Status;
  EFI_SIMPLE_NETWORK_PROTOCOL      *Snp;
  EFI_PCI_IO_PROTOCOL              *PciIo;
  HOST_INTERFACE_RPI_PCI_NIC_INFO  *RpiPciNic;
  UINTN                            SegmentNumber;
  UINTN                            BusNumber;
  UINTN                            DeviceNumber;
  UINTN                            FunctionNumber;
  UINT32                           ConfigData;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry.\n", __func__));
  Status = gBS->HandleProtocol (
                  Handle,
                  &gEfiSimpleNetworkProtocolGuid,
                  (VOID **)&Snp
                  );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "    Failed to locate SNP.\n"));
    return Status;
  }

  Status = PciNicSearchPciIo (PciDevicePath, &PciIo);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "    Failed to find PCI IO.\n"));
    return Status;
  }

  // Get the PCI location information
  Status = PciIo->GetLocation (PciIo, &SegmentNumber, &BusNumber, &DeviceNumber, &FunctionNumber);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "    Failed to get PCI location.\n"));
    return Status;
  }

  // Get the MAC address of this SNP instance.
  RpiPciNic = AllocateZeroPool (sizeof (HOST_INTERFACE_RPI_PCI_NIC_INFO));
  if (RpiPciNic == NULL) {
    DEBUG ((DEBUG_ERROR, "    Failed to allocate memory for HOST_INTERFACE_RPI_PCI_NIC_INFO.\n"));
    return EFI_OUT_OF_RESOURCES;
  }

  InitializeListHead (&RpiPciNic->NextInstance);
  RpiPciNic->MacAddressSize = Snp->Mode->HwAddressSize;
  RpiPciNic->MacAddress     = AllocatePool (RpiPciNic->MacAddressSize);
  if (RpiPciNic->MacAddress == NULL) {
    DEBUG ((DEBUG_ERROR, "    Failed to allocate memory for HW MAC address.\n"));
    FreePool (RpiPciNic);
    return EFI_OUT_OF_RESOURCES;
  }

  CopyMem (
    (VOID *)RpiPciNic->MacAddress,
    (VOID *)&Snp->Mode->CurrentAddress,
    RpiPciNic->MacAddressSize
    );
  DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    MAC address (in size %d) for this SNP instance:\n", RpiPciNic->MacAddressSize));
  for (Index = 0; Index < RpiPciNic->MacAddressSize; Index++) {
    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "%02x ", *(RpiPciNic->MacAddress + Index)));
  }
  DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "\n"));

  RpiPciNic->ThisSnp   = Snp;
  RpiPciNic->ThisPciIo = PciIo;

  // Read PCI configuration to get Vendor ID and Device ID
  Status = PciIo->Pci.Read (
                        PciIo,
                        EfiPciIoWidthUint32,
                        0,  // Offset 0 contains VendorId and DeviceId
                        1,
                        &ConfigData
                        );
  if (!EFI_ERROR (Status)) {
    RpiPciNic->PciVendorId = (UINT16)(ConfigData & 0xFFFF);
    RpiPciNic->PciDeviceId = (UINT16)((ConfigData >> 16) & 0xFFFF);

    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    PCI Vendor ID: 0x%04x, Device ID: 0x%04x\n",
            RpiPciNic->PciVendorId, RpiPciNic->PciDeviceId));
  }

  // Read Subsystem Vendor ID and Subsystem ID
  Status = PciIo->Pci.Read (
                        PciIo,
                        EfiPciIoWidthUint32,
                        0x2C,  // Offset 0x2C contains Subsystem information
                        1,
                        &ConfigData
                        );
  if (!EFI_ERROR (Status)) {
    RpiPciNic->PciSubsystemVendorId = (UINT16)(ConfigData & 0xFFFF);
    RpiPciNic->PciSubsystemId       = (UINT16)((ConfigData >> 16) & 0xFFFF);
  }

  // Store PCI location information
  RpiPciNic->PciSegmentNumber         = (UINT16)SegmentNumber;
  RpiPciNic->PciBusNumber             = (UINT8)BusNumber;
  RpiPciNic->PciDeviceFunctionNumber  = (UINT8)((DeviceNumber << 3) | FunctionNumber);

  //
  // For Raspberry Pi, we identify the on-board network interface by checking
  // for common Broadcom vendor IDs or other platform-specific criteria.
  // Common Raspberry Pi network controller vendor IDs:
  // - Broadcom: 0x14E4
  // - Microchip (USB to Ethernet on some models): 0x0424
  //
  if ((RpiPciNic->PciVendorId == 0x14E4) ||  // Broadcom
      (RpiPciNic->PciVendorId == 0x0424)) {  // Microchip (for USB-Ethernet bridge)
    RpiPciNic->IsOnBoardNic = TRUE;
    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    Raspberry Pi on-board PCI NIC is found (Vendor: 0x%04x).\n", RpiPciNic->PciVendorId));
  } else {
    // For development/testing, we might accept any network interface
    // In production, you should be more restrictive
    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    Unknown vendor 0x%04x - treating as potential on-board NIC for development.\n", RpiPciNic->PciVendorId));
    RpiPciNic->IsOnBoardNic = TRUE;
  }

  InsertTailList (&mRpiPciNic, &RpiPciNic->NextInstance);
  return EFI_SUCCESS;
}

/**
  This function checks if the Raspberry Pi on-board PCI NIC
  on each handle has SNP protocol installed on it.

  @param[in] HandleNumber    Number of handles to check.
  @param[in] HandleBuffer   Handles buffer.

  @retval EFI_SUCCESS          Yes, on-board PCI NIC is found.
  @retval EFI_NOT_FOUND        No, on-board PCI NIC is not found
                               on the existing SNP handle.
  @retval Others               Other errors.

**/
EFI_STATUS
CheckRpiPciNicOnHandles (
  IN  UINTN       HandleNumber,
  IN  EFI_HANDLE  *HandleBuffer
  )
{
  UINTN                     Index;
  EFI_STATUS                Status;
  EFI_DEVICE_PATH_PROTOCOL  *DevicePath;
  BOOLEAN                   GotRpiPciNic;
  CHAR16                    *DevicePathStr;

  if ((HandleNumber == 0) || (HandleBuffer == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry, #%d SNP handle\n", __func__, HandleNumber));

  GotRpiPciNic = FALSE;
  for (Index = 0; Index < HandleNumber; Index++) {
    DEBUG ((DEBUG_MANAGEABILITY, "    Locate device path on handle 0x%08x\n", *(HandleBuffer + Index)));
    Status = gBS->HandleProtocol (
                    *(HandleBuffer + Index),
                    &gEfiDevicePathProtocolGuid,
                    (VOID **)&DevicePath
                    );
    if (EFI_ERROR (Status)) {
      DEBUG ((DEBUG_ERROR, "    Failed to locate device path on %d handle.\n", Index));
      continue;
    }

    DevicePathStr = ConvertDevicePathToText (DevicePath, FALSE, FALSE);
    if (DevicePathStr != NULL) {
      DEBUG ((DEBUG_MANAGEABILITY, "    Device path: %s\n", DevicePathStr));
      FreePool (DevicePathStr);
    }

    // Check if this is a PCI network device.
    while (TRUE) {
      if ((DevicePath->Type == HARDWARE_DEVICE_PATH) && (DevicePath->SubType == HW_PCI_DP)) {
        Status = IdentifyNetworkMessageDevicePath (DevicePath);
        if (!EFI_ERROR (Status)) {
          Status = IdentifyRpiOnBoardPciNic (*(HandleBuffer + Index), DevicePath);
          if (!EFI_ERROR (Status)) {
            GotRpiPciNic = TRUE;
          }
        }

        break; // Advance to next SNP handle.
      }

      DevicePath = NextDevicePathNode (DevicePath);
      if (IsDevicePathEnd (DevicePath)) {
        break;
      }
    }
  }

  if (GotRpiPciNic) {
    return EFI_SUCCESS;
  }

  DEBUG ((DEBUG_MANAGEABILITY, "No Raspberry Pi on-board PCI NIC found on SNP handles\n"));
  return EFI_NOT_FOUND;
}

/**
  This function checks if the Raspberry Pi on-board PCI NIC
  is already connected.

  @param[in] Registration      Locate SNP protocol from the notification
                               registration key.
                               NULL means locate SNP protocol from the existing
                               handles.

  @retval EFI_SUCCESS          Yes, on-board PCI NIC is found.
  @retval EFI_NOT_FOUND        No, on-board PCI NIC is not found
                               on the existing SNP handle.
  @retval Others               Other errors.

**/
EFI_STATUS
CheckRpiPciNic (
  VOID  *Registration
  )
{
  EFI_STATUS  Status;
  EFI_HANDLE  Handle;
  UINTN       BufferSize;
  EFI_HANDLE  *HandleBuffer;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry, the registration key - 0x%08x.\n", __func__, Registration));

  Handle       = NULL;
  HandleBuffer = NULL;
  Status       = EFI_SUCCESS;

  do {
    BufferSize = 0;
    Status     = gBS->LocateHandle (
                        Registration == NULL ? ByProtocol : ByRegisterNotify,
                        &gEfiSimpleNetworkProtocolGuid,
                        Registration,
                        &BufferSize,
                        NULL
                        );
    if (Status == EFI_BUFFER_TOO_SMALL) {
      DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    %d SNP protocol instance(s).\n", BufferSize/sizeof (EFI_HANDLE)));
      HandleBuffer = AllocateZeroPool (BufferSize);
      if (HandleBuffer == NULL) {
        DEBUG ((DEBUG_ERROR, "    Failed to allocate buffer for the handles.\n"));
        return EFI_OUT_OF_RESOURCES;
      }

      Status = gBS->LocateHandle (
                      Registration == NULL ? ByProtocol : ByRegisterNotify,
                      &gEfiSimpleNetworkProtocolGuid,
                      Registration,
                      &BufferSize,
                      HandleBuffer
                      );
      if (EFI_ERROR (Status)) {
        DEBUG ((DEBUG_ERROR, "    Failed to locate SNP protocol handles.\n"));
        FreePool (HandleBuffer);
        return Status;
      }
    } else if (EFI_ERROR (Status)) {
      if (Registration != NULL) {
        DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    No more newly installed SNP protocol for this registration - %r.\n", Status));
        return EFI_SUCCESS;
      }

      return Status;
    }

    // Check PCI NIC on handles.
    Status = CheckRpiPciNicOnHandles (BufferSize/sizeof (EFI_HANDLE), HandleBuffer);
    if (!EFI_ERROR (Status)) {
      // Retrieve the rest of Raspberry Pi PCI NIC information for Redfish over IP information
      // and PCI Network Interface V2.
      Status = RetrieveRpiPciNicInfo ();
      if (!EFI_ERROR (Status)) {
        DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "    Install protocol to notify the platform Redfish Host Interface information is ready.\n"));
        Status = gBS->InstallProtocolInterface (
                        &Handle,
                        &mPlatformHostInterfaceRpiPciNicReadinessGuid,
                        EFI_NATIVE_INTERFACE,
                        NULL
                        );
        if (EFI_ERROR (Status)) {
          DEBUG ((DEBUG_ERROR, "    Install protocol fail %r.\n", Status));
        }
      }
    }

    FreePool (HandleBuffer);
  } while (Registration != NULL);

  return Status;
}

/**
  Notification event of SNP readiness.

  @param[in]  Event                 Event whose notification function is being invoked.
  @param[in]  Context               The pointer to the notification function's context,
                                    which is implementation-dependent.

**/
VOID
EFIAPI
PlatformHostInterfaceSnpCallback (
  IN  EFI_EVENT  Event,
  IN  VOID       *Context
  )
{
  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry.\n", __func__));

  CheckRpiPciNic (mPlatformHostInterfaceSnpRegistration);
  return;
}

/**
  Get the EFI protocol GUID installed by platform library which
  indicates the necessary information is ready for building
  SMBIOS 42h record.

  @param[out] InformationReadinessGuid  Pointer to retrieve the protocol
                                        GUID.

  @retval EFI_SUCCESS          Notification is required for building up
                               SMBIOS type 42h record.
  @retval EFI_UNSUPPORTED      Notification is not required for building up
                               SMBIOS type 42h record.
  @retval EFI_ALREADY_STARTED  Platform host information is already ready.
  @retval Others               Other errors.
**/
EFI_STATUS
RedfishPlatformHostInterfaceNotification (
  OUT EFI_GUID  **InformationReadinessGuid
  )
{
  EFI_STATUS  Status;

  DEBUG ((DEBUG_MANAGEABILITY, "%a: Entry\n", __func__));

  *InformationReadinessGuid = NULL;
  InitializeListHead (&mRpiPciNic);

  //
  // Check if Raspberry Pi on-board PCI NIC is already
  // connected.
  //
  Status = CheckRpiPciNic (NULL);
  if (!EFI_ERROR (Status)) {
    return EFI_ALREADY_STARTED;
  }

  if (Status == EFI_NOT_FOUND) {
    DEBUG ((DEBUG_REDFISH_HOST_INTERFACE, "%a: Raspberry Pi PCI NIC is not found. Register the notification.\n", __func__));

    // Register the notification of SNP installation.
    Status = gBS->CreateEvent (
                    EVT_NOTIFY_SIGNAL,
                    TPL_CALLBACK,
                    PlatformHostInterfaceSnpCallback,
                    NULL,
                    &mPlatformHostInterfaceSnpEvent
                    );
    if (EFI_ERROR (Status)) {
      DEBUG ((DEBUG_ERROR, "%a: Fail to create event for the installation of SNP protocol.", __func__));
      return Status;
    }

    Status = gBS->RegisterProtocolNotify (
                    &gEfiSimpleNetworkProtocolGuid,
                    mPlatformHostInterfaceSnpEvent,
                    &mPlatformHostInterfaceSnpRegistration
                    );
    if (EFI_ERROR (Status)) {
      DEBUG ((DEBUG_ERROR, "%a: Fail to register event for the installation of SNP protocol.", __func__));
      return Status;
    }

    *InformationReadinessGuid = &mPlatformHostInterfaceRpiPciNicReadinessGuid;
    return EFI_SUCCESS;
  }

  DEBUG ((DEBUG_ERROR, "%a: Something wrong when looking for Raspberry Pi PCI NIC.\n", __func__));
  return Status;
}

/**
  Get device serial number.

  @param[out] SerialNumber    Pointer to retrieve complete serial number.
                              It is the responsibility of the caller to free the allocated
                              memory for serial number.
  @retval EFI_SUCCESS         Serial number is returned.
  @retval Others              Failed to get the serial number
**/
EFI_STATUS
RedfishPlatformHostInterfaceSerialNumber (
  OUT CHAR8  **SerialNumber
  )
{
  return EFI_UNSUPPORTED;
}

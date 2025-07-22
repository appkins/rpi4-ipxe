/** @file
  Raspberry Pi implementation of RedfishPlatformHostInterfaceLib for external Redfish service

  Copyright (c) 2019, Intel Corporation. All rights reserved.<BR>
  (C) Copyright 2020 Hewlett Packard Enterprise Development LP<BR>
  Copyright (C) 2022 Advanced Micro Devices, Inc. All rights reserved.<BR>
  Copyright (c) 2025, NVIDIA CORPORATION & AFFILIATES. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#include <Uefi.h>
#include <Library/PcdLib.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/DevicePathLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PrintLib.h>
#include <Library/RedfishHostInterfaceLib.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Protocol/RpiFirmware.h>

#include <Pcd/RestExServiceDevicePath.h>

#define VERBOSE_COLUME_SIZE  (16)
#define REDFISH_HOSTNAME_STR_STORAGE_SIZE  64

STATIC RASPBERRY_PI_FIRMWARE_PROTOCOL *mFwProtocol;

REDFISH_OVER_IP_PROTOCOL_DATA  *mRedfishOverIpProtocolData;
UINT8                          mRedfishProtocolDataSize;

/**
  Get the MAC address of NIC.

  @param[out] MacAddress      Pointer to retrieve MAC address

  @retval   EFI_SUCCESS      MAC address is returned in MacAddress

**/
EFI_STATUS
GetMacAddressInformation (
  OUT EFI_MAC_ADDRESS  *MacAddress
  )
{
  EFI_STATUS Status;

  if (MacAddress == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  if (mFwProtocol == NULL) {
    DEBUG ((DEBUG_ERROR, "RedfishPlatformHostInterfaceLib: Firmware protocol not available\n"));
    return EFI_NOT_READY;
  }

  //
  // Get the MAC address from the firmware.
  //
  Status = mFwProtocol->GetMacAddress (MacAddress->Addr);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "RedfishPlatformHostInterfaceLib: Failed to get MAC address - %r\n", Status));
    return EFI_NOT_FOUND;
  }

  return EFI_SUCCESS;
}

/**
  Get platform Redfish host interface device descriptor.

  @param[out] DeviceType        Pointer to retrieve device type.
  @param[out] DeviceDescriptor  Pointer to retrieve REDFISH_INTERFACE_DATA, caller has to free
                                this memory using FreePool().
  @retval EFI_SUCCESS     Device descriptor is returned successfully in DeviceDescriptor.
  @retval EFI_NOT_FOUND   No Redfish host interface descriptor provided on this platform.
  @retval Others          Fail to get device descriptor.
**/
EFI_STATUS
RedfishPlatformHostInterfaceDeviceDescriptor (
  OUT UINT8                   *DeviceType,
  OUT REDFISH_INTERFACE_DATA  **DeviceDescriptor
  )
{
  EFI_STATUS                                  Status;
  EFI_MAC_ADDRESS                             MacAddress;
  REDFISH_INTERFACE_DATA                      *RedfishInterfaceData;
  PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2  *ThisDeviceDescriptor;

  RedfishInterfaceData = AllocateZeroPool (sizeof (PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2) + 1);
  if (RedfishInterfaceData == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  RedfishInterfaceData->DeviceType = REDFISH_HOST_INTERFACE_DEVICE_TYPE_PCI_PCIE_V2;
  //
  // Fill up device type information.
  //
  ThisDeviceDescriptor         = (PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2 *)((UINT8 *)RedfishInterfaceData + 1);
  ThisDeviceDescriptor->Length = sizeof (PCI_OR_PCIE_INTERFACE_DEVICE_DESCRIPTOR_V2) + 1;
  Status                       = GetMacAddressInformation (&MacAddress);
  if (EFI_ERROR (Status)) {
    FreePool (RedfishInterfaceData);
    return EFI_NOT_FOUND;
  }

  CopyMem ((VOID *)&ThisDeviceDescriptor->MacAddress, (VOID *)&MacAddress, sizeof (ThisDeviceDescriptor->MacAddress));
  *DeviceType       = REDFISH_HOST_INTERFACE_DEVICE_TYPE_PCI_PCIE_V2;
  *DeviceDescriptor = RedfishInterfaceData;
  return EFI_SUCCESS;
}

/**
  Get platform Redfish host interface protocol data.
  Caller should pass NULL in ProtocolRecord to retrive the first protocol record.
  Then continuously pass previous ProtocolRecord for retrieving the next ProtocolRecord.

  @param[out] ProtocolRecord     Pointer to retrieve the protocol record.
                                 caller has to free the new protocol record returned from
                                 this function using FreePool().
  @param[in] IndexOfProtocolData The index of protocol data.

  @retval EFI_SUCCESS     Protocol records are all returned.
  @retval EFI_NOT_FOUND   No more protocol records.
  @retval Others          Fail to get protocol records.
**/
EFI_STATUS
RedfishPlatformHostInterfaceProtocolData (
  OUT MC_HOST_INTERFACE_PROTOCOL_RECORD  **ProtocolRecord,
  IN UINT8                               IndexOfProtocolData
  )
{
  MC_HOST_INTERFACE_PROTOCOL_RECORD  *ThisProtocolRecord;

  if (mRedfishOverIpProtocolData == NULL) {
    return EFI_NOT_FOUND;
  }

  if (IndexOfProtocolData == 0) {
    //
    // Return the first Redfish protocol data to caller. We only have
    // one protocol data in this case.
    //
    ThisProtocolRecord                      = (MC_HOST_INTERFACE_PROTOCOL_RECORD *)AllocatePool (mRedfishProtocolDataSize + sizeof (MC_HOST_INTERFACE_PROTOCOL_RECORD) - 1);
    ThisProtocolRecord->ProtocolType        = MCHostInterfaceProtocolTypeRedfishOverIP;
    ThisProtocolRecord->ProtocolTypeDataLen = mRedfishProtocolDataSize;
    CopyMem ((VOID *)&ThisProtocolRecord->ProtocolTypeData, (VOID *)mRedfishOverIpProtocolData, mRedfishProtocolDataSize);
    *ProtocolRecord = ThisProtocolRecord;
    return EFI_SUCCESS;
  }

  return EFI_SUCCESS;
}

/**
  Get Redfish host interface protocol data from PCD.

  @param[out] RedfishProtocolData      Pointer to retrieve REDFISH_OVER_IP_PROTOCOL_DATA.
  @param[out] RedfishProtocolDataSize  Size of REDFISH_OVER_IP_PROTOCOL_DATA.

  @retval EFI_SUCCESS  REDFISH_OVER_IP_PROTOCOL_DATA is returned successfully.
**/
EFI_STATUS
GetRedfishRecordFromConfiguration (
  OUT REDFISH_OVER_IP_PROTOCOL_DATA  **RedfishProtocolData,
  OUT UINT8                          *RedfishProtocolDataSize
  )
{
  CHAR8    *HostnamePtr;
  CHAR8    RedfishHostName[REDFISH_HOSTNAME_STR_STORAGE_SIZE];
  UINT8    HostNameSize;
  UINT16   RedfishServicePort;

  if ((RedfishProtocolData == NULL) || (RedfishProtocolDataSize == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  // Get hostname from PCD
  HostnamePtr = (CHAR8 *)PcdGetPtr (PcdRedfishHostName);
  if (HostnamePtr == NULL || AsciiStrLen (HostnamePtr) == 0) {
    DEBUG ((DEBUG_ERROR, "RedfishPlatformHostInterfaceLib: No hostname configured in PCD\n"));
    return EFI_NOT_FOUND;
  }

  // Get port from PCD
  RedfishServicePort = PcdGet16 (PcdRedfishServicePort);
  if (RedfishServicePort == 0) {
    RedfishServicePort = 5000;
  }

  // Copy hostname
  AsciiStrCpyS (RedfishHostName, sizeof(RedfishHostName), HostnamePtr);
  HostNameSize = (UINT8)AsciiStrLen (RedfishHostName) + 1;

  //
  // Calculate Protocol Data Size.
  //
  *RedfishProtocolDataSize = sizeof (REDFISH_OVER_IP_PROTOCOL_DATA) - 1 + HostNameSize;

  //
  // Allocate Protocol Data.
  //
  *RedfishProtocolData = (REDFISH_OVER_IP_PROTOCOL_DATA *)AllocateZeroPool (*RedfishProtocolDataSize);
  if (*RedfishProtocolData == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  // Service UUID
  if (StrLen ((CONST CHAR16 *)PcdGetPtr (PcdRedfishServiceUuid)) != 0) {
    StrToGuid ((CONST CHAR16 *)PcdGetPtr (PcdRedfishServiceUuid), &(*RedfishProtocolData)->ServiceUuid);
  }

  // Fill in the protocol data
  (*RedfishProtocolData)->HostIpAssignmentType = REDFISH_HOST_INTERFACE_HOST_IP_ASSIGNMENT_TYPE_DHCP;  // DHCP
  (*RedfishProtocolData)->HostIpAddressFormat  = REDFISH_HOST_INTERFACE_HOST_IP_ADDRESS_FORMAT_IP4;  // IPv4

  // Redfish Service configuration - external service
  (*RedfishProtocolData)->RedfishServiceIpDiscoveryType = REDFISH_HOST_INTERFACE_HOST_IP_ASSIGNMENT_TYPE_STATIC;  // Use static configuration (hostname)
  (*RedfishProtocolData)->RedfishServiceIpAddressFormat = REDFISH_HOST_INTERFACE_HOST_IP_ADDRESS_FORMAT_IP4;  // IPv4 (though we're using hostname)

  // Set service port
  (*RedfishProtocolData)->RedfishServiceIpPort = RedfishServicePort;
  (*RedfishProtocolData)->RedfishServiceVlanId = 0xffffffff;  // No VLAN

  // Always zero IP address and mask fields before parsing hostname or IP
  ZeroMem ((*RedfishProtocolData)->RedfishServiceIpAddress, sizeof((*RedfishProtocolData)->RedfishServiceIpAddress));
  ZeroMem ((*RedfishProtocolData)->RedfishServiceIpMask, sizeof((*RedfishProtocolData)->RedfishServiceIpMask));

  EFI_STATUS  Status;

  // Set hostname
  // Try to parse as IPv4 address first
  Status = StrToIpv4Address (RedfishHostName, NULL, (*RedfishProtocolData)->RedfishServiceIpAddress, NULL);
  if (!EFI_ERROR (Status)) {
    // It's a valid IPv4 address
    (*RedfishProtocolData)->RedfishServiceIpAddressFormat = REDFISH_HOST_INTERFACE_HOST_IP_ADDRESS_FORMAT_IP4;
    (*RedfishProtocolData)->RedfishServiceIpDiscoveryType = REDFISH_HOST_INTERFACE_HOST_IP_ASSIGNMENT_TYPE_STATIC;
    DEBUG ((DEBUG_INFO, "RedfishPlatformHostInterfaceLib: Configured external service IPv4 %a:%d\n",
        RedfishHostName, RedfishServicePort));
  } else {
    // Try to parse as IPv6 address
    UINT8 Ipv6Address[16];
    ZeroMem (Ipv6Address, sizeof(Ipv6Address));

    Status = StrToIpv6Address (RedfishHostName, NULL, Ipv6Address, NULL);
    if (!EFI_ERROR (Status)) {
      // It's a valid IPv6 address
      (*RedfishProtocolData)->RedfishServiceIpAddressFormat = REDFISH_HOST_INTERFACE_HOST_IP_ADDRESS_FORMAT_IP6;
      (*RedfishProtocolData)->RedfishServiceIpDiscoveryType = REDFISH_HOST_INTERFACE_HOST_IP_ASSIGNMENT_TYPE_STATIC;
      // Copy IPv6 address (first 4 bytes for IPv4 compatibility)
      CopyMem((*RedfishProtocolData)->RedfishServiceIpAddress, Ipv6Address, sizeof((*RedfishProtocolData)->RedfishServiceIpAddress));
      DEBUG ((DEBUG_INFO, "RedfishPlatformHostInterfaceLib: Configured external service IPv6 %a:%d\n",
          RedfishHostName, RedfishServicePort));
    } else {
      // It's a hostname/domain name
      (*RedfishProtocolData)->RedfishServiceHostnameLength = HostNameSize - 1; // Exclude null terminator
      Status = AsciiStrCpyS ((CHAR8 *)((*RedfishProtocolData)->RedfishServiceHostname), HostNameSize, RedfishHostName);
      if (EFI_ERROR (Status)) {
        FreePool (*RedfishProtocolData);
        *RedfishProtocolData = NULL;
        return Status;
      }
      DEBUG ((DEBUG_INFO, "RedfishPlatformHostInterfaceLib: Configured external service hostname %a:%d\n",
          RedfishHostName, RedfishServicePort));
    }
  }

  return EFI_SUCCESS;
}

/**
  Construct Redfish host interface protocol data.

  @param ImageHandle     The image handle.
  @param SystemTable     The system table.

  @retval  EFI_SUCEESS  Install Boot manager menu success.
  @retval  Other        Return error status.

**/
EFI_STATUS
EFIAPI
RedfishPlatformHostInterfaceConstructor (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;

  // Locate the Raspberry Pi firmware protocol for MAC address retrieval
  Status = gBS->LocateProtocol (
                  &gRaspberryPiFirmwareProtocolGuid,
                  NULL,
                  (VOID **)&mFwProtocol
                  );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_WARN, "RedfishPlatformHostInterfaceLib: Raspberry Pi firmware protocol not found - %r\n", Status));
    mFwProtocol = NULL;
  }

  Status = GetRedfishRecordFromConfiguration (&mRedfishOverIpProtocolData, &mRedfishProtocolDataSize);
  DEBUG ((DEBUG_INFO, "%a: GetRedfishRecordFromConfiguration() - %r\n", __func__, Status));

  return EFI_SUCCESS;
}

/**
  Get the EFI protocol GUID installed by platform library which
  indicates the necessary information is ready for building
  SMBIOS 42h record.

  @param[out] InformationReadinessGuid  Pointer to retrive the protocol
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
  return EFI_ALREADY_STARTED;
}

/**
  Get USB device serial number.

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
  EFI_STATUS Status;
  UINT64     Serial;
  CHAR8      *SerialString;
  UINTN      SerialStringSize;

  if (SerialNumber == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  if (mFwProtocol == NULL) {
    DEBUG ((DEBUG_ERROR, "RedfishPlatformHostInterfaceLib: Firmware protocol not available\n"));
    return EFI_NOT_READY;
  }

  //
  // Get the serial number from the firmware as UINT64
  //
  Status = mFwProtocol->GetSerial (&Serial);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "Failed to get board serial: %r\n", Status));
    return Status;
  }

  //
  // Convert UINT64 serial to ASCII string
  // Allocate buffer for "0x" + 16 hex digits + null terminator
  //
  SerialStringSize = 19; // "0x" + 16 hex chars + '\0'
  SerialString = AllocateZeroPool (SerialStringSize);
  if (SerialString == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  //
  // Format as hexadecimal string
  //
  AsciiSPrint (SerialString, SerialStringSize, "0x%016lX", Serial);

  *SerialNumber = SerialString;
  return EFI_SUCCESS;
}

/** @file
  Early Redfish Startup Driver for Raspberry Pi

  This driver provides early initialization of Redfish services and triggers
  the RedfishFeatureCoreDxe startup event to ensure proper initialization
  order in the DXE phase.

  Copyright (c) 2024, Raspberry Pi Foundation. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#ifndef __REDFISH_EARLY_STARTUP_DXE_H__
#define __REDFISH_EARLY_STARTUP_DXE_H__

#include <Uefi.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/UefiLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiDriverEntryPoint.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/NetLib.h>
#include <Library/PrintLib.h>
#include <Library/PcdLib.h>

#include <Protocol/RestEx.h>

#include <Guid/EventGroup.h>

//
// GUID for our custom startup event
//
#define REDFISH_EARLY_STARTUP_EVENT_GUID \
  { \
    0x12345678, 0x1234, 0x5678, { 0x9A, 0xBC, 0x12, 0x34, 0x56, 0x78, 0x90, 0x12 } \
  }

//
// Config DXE Form Set GUID for Redfish variables
//
#define CONFIG_DXE_FORMSET_GUID \
  { \
    0x8399a787, 0x108e, 0x4e53, { 0x9e, 0xde, 0x4b, 0x18, 0xcc, 0x9e, 0xab, 0x3b } \
  }

//
// Global variables
//
extern EFI_GUID gRedfishEarlyStartupEventGuid;
extern EFI_GUID gConfigDxeFormSetGuid;

/**
  Initialize Redfish service variables with default values.

  @retval EFI_SUCCESS           Variables initialized successfully
  @retval Others                Error occurred during initialization
**/
EFI_STATUS
InitializeRedfishServiceVariables (
  VOID
  );

/**
  Create and install a minimal REST EX protocol instance.

  @retval EFI_SUCCESS           REST EX protocol installed successfully
  @retval Others                Error occurred during installation
**/
EFI_STATUS
InstallMinimalRestExProtocol (
  VOID
  );

/**
  Signal the RedfishFeatureCoreDxe startup event.

  @retval EFI_SUCCESS           Event signaled successfully
  @retval Others                Error occurred during signaling
**/
EFI_STATUS
SignalRedfishFeatureStartupEvent (
  VOID
  );

#endif // __REDFISH_EARLY_STARTUP_DXE_H__

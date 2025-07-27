/** @file
  Early Redfish Startup Driver for Raspberry Pi

  This driver provides early initialization of Redfish services and triggers
  the RedfishFeatureCoreDxe startup event to ensure proper initialization
  order in the DXE phase.

  Copyright (c) 2024, Raspberry Pi Foundation. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#include "RedfishEarlyStartupDxe.h"

//
// Global GUID definitions
//
EFI_GUID gRedfishEarlyStartupEventGuid = REDFISH_EARLY_STARTUP_EVENT_GUID;
EFI_GUID gConfigDxeFormSetGuid         = CONFIG_DXE_FORMSET_GUID;

/**
  Initialize Redfish service variables with default values.

  @retval EFI_SUCCESS           Variables initialized successfully
  @retval Others                Error occurred during initialization
**/
EFI_STATUS
InitializeRedfishServiceVariables(VOID)
{
  EFI_STATUS Status;
  CHAR16    *RedfishServiceIpAddress;
  UINT16     RedfishServiceIpPort;
  UINTN      DataSize;

  DEBUG((DEBUG_INFO, "%a: Initializing Redfish service variables\n", __func__));

  //
  // Set default Redfish service IP address (localhost for simulator)
  //
  RedfishServiceIpAddress = L"127.0.0.1";
  DataSize                = StrSize(RedfishServiceIpAddress);

  Status = gRT->SetVariable(
      L"RedfishServiceIpAddress", &gConfigDxeFormSetGuid,
      EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS |
          EFI_VARIABLE_NON_VOLATILE,
      DataSize, RedfishServiceIpAddress);
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_WARN, "%a: Failed to set RedfishServiceIpAddress variable: %r\n",
         __func__, Status));
    // Continue anyway, as this is not critical
  }
  else {
    DEBUG(
        (DEBUG_INFO, "%a: Set RedfishServiceIpAddress to %s\n", __func__,
         RedfishServiceIpAddress));
  }

  //
  // Set default Redfish service port (5000 for simulator)
  //
  RedfishServiceIpPort = 5000;
  DataSize             = sizeof(RedfishServiceIpPort);

  Status = gRT->SetVariable(
      L"RedfishServiceIpPort", &gConfigDxeFormSetGuid,
      EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS |
          EFI_VARIABLE_NON_VOLATILE,
      DataSize, &RedfishServiceIpPort);
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_WARN, "%a: Failed to set RedfishServiceIpPort variable: %r\n",
         __func__, Status));
    // Continue anyway, as this is not critical
  }
  else {
    DEBUG(
        (DEBUG_INFO, "%a: Set RedfishServiceIpPort to %d\n", __func__,
         RedfishServiceIpPort));
  }

  return EFI_SUCCESS;
}

/**
  Create and install a minimal REST EX protocol instance.

  This provides the EFI REST EX protocol that RedfishFeatureCoreDxe needs
  to trigger early in the DXE phase.

  @retval EFI_SUCCESS           REST EX protocol installed successfully
  @retval Others                Error occurred during installation
**/
EFI_STATUS
InstallMinimalRestExProtocol(VOID)
{
  // For now, we'll skip installing the actual REST EX protocol
  // The key is to signal the startup event, which doesn't require
  // a full REST EX implementation for the initial trigger

  DEBUG((DEBUG_INFO, "%a: REST EX protocol installation deferred\n", __func__));
  DEBUG(
      (DEBUG_INFO,
       "%a: Early startup can proceed without full REST implementation\n",
       __func__));

  return EFI_SUCCESS;
}

/**
  Signal the RedfishFeatureCoreDxe startup event.

  @retval EFI_SUCCESS           Event signaled successfully
  @retval Others                Error occurred during signaling
**/
EFI_STATUS
SignalRedfishFeatureStartupEvent(VOID)
{
  EFI_STATUS Status;
  EFI_GUID  *FeatureDriverStartupEventGuid;
  EFI_EVENT  FeatureDriverStartupEvent;

  DEBUG(
      (DEBUG_INFO, "%a: Signaling RedfishFeatureCoreDxe startup event\n",
       __func__));

  //
  // Get the startup event GUID from PCD
  //
  FeatureDriverStartupEventGuid =
      (EFI_GUID *)PcdGetPtr(PcdEdkIIRedfishFeatureDriverStartupEventGuid);
  if (FeatureDriverStartupEventGuid == NULL) {
    DEBUG(
        (DEBUG_ERROR,
         "%a: PcdEdkIIRedfishFeatureDriverStartupEventGuid is NULL\n",
         __func__));
    return EFI_NOT_FOUND;
  }

  DEBUG(
      (DEBUG_MANAGEABILITY, "%a: Using startup event GUID from PCD\n",
       __func__));

  //
  // Create an event with the startup GUID to signal RedfishFeatureCoreDxe
  //
  Status = gBS->CreateEventEx(
      EVT_NOTIFY_SIGNAL, TPL_CALLBACK,
      NULL, // No callback needed, just signaling
      NULL, FeatureDriverStartupEventGuid, &FeatureDriverStartupEvent);
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_ERROR,
         "%a: Failed to create RedfishFeatureDriverStartup event: %r\n",
         __func__, Status));
    return Status;
  }

  //
  // Signal the event to trigger RedfishFeatureCoreDxe startup
  //
  Status = gBS->SignalEvent(FeatureDriverStartupEvent);
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_ERROR,
         "%a: Failed to signal RedfishFeatureDriverStartup event: %r\n",
         __func__, Status));
  }
  else {
    DEBUG(
        (DEBUG_MANAGEABILITY,
         "%a: Successfully signaled RedfishFeatureDriverStartup event\n",
         __func__));
  }

  //
  // Close the event
  //
  gBS->CloseEvent(FeatureDriverStartupEvent);

  return Status;
}

/**
  Entry point for the Redfish Early Startup DXE driver.

  @param[in] ImageHandle    The firmware allocated handle for the UEFI image.
  @param[in] SystemTable    A pointer to the EFI System Table.

  @retval EFI_SUCCESS       The operation completed successfully.
  @retval Others            An unexpected error occurred.
**/
EFI_STATUS
EFIAPI
RedfishEarlyStartupDxeEntryPoint(
    IN EFI_HANDLE ImageHandle, IN EFI_SYSTEM_TABLE *SystemTable)
{
  EFI_STATUS Status;

  DEBUG(
      (DEBUG_INFO, "%a: Redfish Early Startup DXE driver entry point\n",
       __func__));

  //
  // Step 1: Initialize Redfish service variables with default values
  //
  Status = InitializeRedfishServiceVariables();
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_WARN, "%a: Failed to initialize Redfish service variables: %r\n",
         __func__, Status));
    // Continue anyway, as this is not critical for the startup event
  }

  //
  // Step 2: Install minimal REST EX protocol (deferred for now)
  //
  Status = InstallMinimalRestExProtocol();
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_WARN, "%a: Failed to install REST EX protocol: %r\n", __func__,
         Status));
    // Continue anyway, the event signaling is more important
  }

  //
  // Step 3: Signal the RedfishFeatureCoreDxe startup event
  // This is the critical step that ensures the Redfish feature drivers get
  // initialized
  //
  Status = SignalRedfishFeatureStartupEvent();
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_ERROR,
         "%a: Failed to signal RedfishFeatureCoreDxe startup event: %r\n",
         __func__, Status));
    return Status;
  }

  DEBUG(
      (DEBUG_INFO,
       "%a: Redfish Early Startup DXE driver initialization complete\n",
       __func__));
  return EFI_SUCCESS;
}

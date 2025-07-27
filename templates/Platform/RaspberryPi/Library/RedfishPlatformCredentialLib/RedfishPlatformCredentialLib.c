/** @file
  Raspberry Pi RedfishPlatformCredentialLib instance

  This implementation supports authentication via PCDs and EFI variables,
  with conditional authentication based on
PcdRedfishServiceAuthenticationEnabled.

  Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
  Copyright (c) 2025, Raspberry Pi Foundation. All rights reserved.

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PcdLib.h>
#include <Library/UefiLib.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Uefi.h>

#include <Protocol/EdkIIRedfishCredential.h>

// Raspberry Pi specific GUID for variables - should match ConfigDxe
#define RASPBERRY_PI_VARIABLES_GUID                                            \
  {0xFB833014, 0x7A04, 0x42F6, {0x88, 0x1A, 0x37, 0x4D, 0x9D, 0xB6, 0x29, 0x3A}}

#define REDFISH_USER_ID_VARIABLE_NAME L"RedfishServiceUserId"
#define REDFISH_PASSWORD_VARIABLE_NAME L"RedfishServicePassword"
#define REDFISH_AUTH_ENABLED_VARIABLE_NAME                                     \
  L"RedfishServiceAuthenticationEnabled"

BOOLEAN mStopRedfishService = FALSE;

EFI_STATUS
EFIAPI
LibStopRedfishService(
    IN EDKII_REDFISH_CREDENTIAL_PROTOCOL         *This,
    IN EDKII_REDFISH_CREDENTIAL_STOP_SERVICE_TYPE ServiceStopType);

/**
  Get authentication setting from EFI variable.

  @param[out]  AuthEnabled    Pointer to store authentication enabled setting.

  @retval EFI_SUCCESS         Authentication setting retrieved successfully.
  @retval EFI_NOT_FOUND       Variable not found, use PCD default.
  @retval Others              Error occurred.

**/
EFI_STATUS
GetAuthenticationSetting(OUT BOOLEAN *AuthEnabled)
{
  EFI_STATUS Status;
  UINTN      DataSize;
  EFI_GUID   RpiVariablesGuid = RASPBERRY_PI_VARIABLES_GUID;

  DataSize = sizeof(BOOLEAN);
  Status   = gRT->GetVariable(
      REDFISH_AUTH_ENABLED_VARIABLE_NAME, &RpiVariablesGuid, NULL, &DataSize,
      AuthEnabled);

  if (EFI_ERROR(Status)) {
    // If variable doesn't exist, use default (authentication disabled)
    *AuthEnabled = FALSE;
    DEBUG(
        (DEBUG_INFO, "%a: Using default authentication: Disabled\n", __func__));
    return EFI_SUCCESS;
  }

  DEBUG(
      (DEBUG_INFO, "%a: Authentication from variable: %a\n", __func__,
       *AuthEnabled ? "Enabled" : "Disabled"));
  return EFI_SUCCESS;
}

/**
  Get credential string from EFI variable with fallback to PCD.

  @param[in]   VariableName   Variable name to retrieve.
  @param[in]   PcdString      PCD string to use as fallback.
  @param[out]  Credential     Allocated string with credential.

  @retval EFI_SUCCESS         Credential retrieved successfully.
  @retval EFI_OUT_OF_RESOURCES Memory allocation failed.
  @retval EFI_INVALID_PARAMETER Invalid parameters or empty credential.

**/
EFI_STATUS
GetCredentialString(
    IN CHAR16 *VariableName, IN CHAR8 *PcdString, OUT CHAR8 **Credential)
{
  EFI_STATUS Status;
  UINTN      DataSize;
  CHAR8     *VariableData;
  CHAR8     *SourceString;
  UINTN      StringSize;
  EFI_GUID   RpiVariablesGuid = RASPBERRY_PI_VARIABLES_GUID;

  if ((VariableName == NULL) || (Credential == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  VariableData = NULL;
  DataSize     = 0;

  // First try to get the variable size
  Status =
      gRT->GetVariable(VariableName, &RpiVariablesGuid, NULL, &DataSize, NULL);

  if (Status == EFI_BUFFER_TOO_SMALL) {
    // Allocate buffer and get the variable
    VariableData = AllocateZeroPool(DataSize);
    if (VariableData == NULL) {
      return EFI_OUT_OF_RESOURCES;
    }

    Status = gRT->GetVariable(
        VariableName, &RpiVariablesGuid, NULL, &DataSize, VariableData);

    if (!EFI_ERROR(Status) && (AsciiStrLen(VariableData) > 0)) {
      SourceString = VariableData;
      DEBUG((DEBUG_INFO, "%a: Using variable %s\n", __func__, VariableName));
    }
    else {
      FreePool(VariableData);
      VariableData = NULL;
      SourceString = PcdString;
      DEBUG(
          (DEBUG_INFO, "%a: Variable %s invalid, using PCD\n", __func__,
           VariableName));
    }
  }
  else {
    // Variable doesn't exist, use PCD
    SourceString = PcdString;
    DEBUG(
        (DEBUG_INFO, "%a: Variable %s not found, using PCD\n", __func__,
         VariableName));
  }

  if ((SourceString == NULL) || (AsciiStrLen(SourceString) == 0)) {
    if (VariableData != NULL) {
      FreePool(VariableData);
    }
    return EFI_INVALID_PARAMETER;
  }

  // Allocate and copy the credential string
  StringSize  = AsciiStrSize(SourceString);
  *Credential = AllocateZeroPool(StringSize);
  if (*Credential == NULL) {
    if (VariableData != NULL) {
      FreePool(VariableData);
    }
    return EFI_OUT_OF_RESOURCES;
  }

  CopyMem(*Credential, SourceString, StringSize);

  if (VariableData != NULL) {
    FreePool(VariableData);
  }

  return EFI_SUCCESS;
}

/**
  Return the credential for accessing Redfish service.

  @param[out]  AuthMethod     The authentication method.
  @param[out]  UserId         User ID.
  @param[out]  Password       User password.

  @retval EFI_SUCCESS              Get the authentication information
successfully.
  @retval EFI_OUT_OF_RESOURCES     There are not enough memory resources.
  @retval EFI_INVALID_PARAMETER    Invalid parameters or credentials.

**/
EFI_STATUS
GetRedfishCredential(
    OUT EDKII_REDFISH_AUTH_METHOD *AuthMethod, OUT CHAR8 **UserId,
    OUT CHAR8 **Password)
{
  EFI_STATUS Status;
  BOOLEAN    AuthEnabled;

  // Check if authentication is enabled
  Status = GetAuthenticationSetting(&AuthEnabled);
  if (EFI_ERROR(Status)) {
    DEBUG(
        (DEBUG_ERROR, "%a: Failed to get authentication setting - %r\n",
         __func__, Status));
    return Status;
  }

  if (!AuthEnabled) {
    // Authentication disabled - use AuthMethodNone
    *AuthMethod = AuthMethodNone;
    *UserId     = NULL;
    *Password   = NULL;
    DEBUG(
        (DEBUG_INFO, "%a: Authentication disabled, using AuthMethodNone\n",
         __func__));
    return EFI_SUCCESS;
  }

  // Authentication enabled - use HTTP Basic with credentials
  *AuthMethod = AuthMethodHttpBasic;

  // Get User ID
  Status = GetCredentialString(
      REDFISH_USER_ID_VARIABLE_NAME,
      "root", // Default fallback user ID - matches simulator
      UserId);
  if (EFI_ERROR(Status)) {
    DEBUG((DEBUG_ERROR, "%a: Failed to get User ID - %r\n", __func__, Status));
    return Status;
  }

  // Get Password
  Status = GetCredentialString(
      REDFISH_PASSWORD_VARIABLE_NAME,
      "password123456", // Default fallback password - matches simulator
      Password);
  if (EFI_ERROR(Status)) {
    DEBUG((DEBUG_ERROR, "%a: Failed to get Password - %r\n", __func__, Status));
    FreePool(*UserId);
    *UserId = NULL;
    return Status;
  }

  DEBUG((DEBUG_INFO, "%a: Using HTTP Basic authentication\n", __func__));
  return EFI_SUCCESS;
}

/**
  Retrieve platform's Redfish authentication information.

  This functions returns the Redfish authentication method together with the
user Id and password.
  - For AuthMethodNone, the UserId and Password could be used for HTTP header
authentication as defined by RFC7235.
  - For AuthMethodRedfishSession, the UserId and Password could be used for
Redfish session login as defined by  Redfish API specification (DSP0266).

  Callers are responsible for and freeing the returned string storage.

  @param[in]   This                Pointer to EDKII_REDFISH_CREDENTIAL_PROTOCOL
instance.
  @param[out]  AuthMethod          Type of Redfish authentication method.
  @param[out]  UserId              The pointer to store the returned UserId
string.
  @param[out]  Password            The pointer to store the returned Password
string.

  @retval EFI_SUCCESS              Get the authentication information
successfully.
  @retval EFI_ACCESS_DENIED        SecureBoot is disabled after EndOfDxe.
  @retval EFI_INVALID_PARAMETER    This or AuthMethod or UserId or Password is
NULL.
  @retval EFI_OUT_OF_RESOURCES     There are not enough memory resources.
  @retval EFI_UNSUPPORTED          Unsupported authentication method is found.

**/
EFI_STATUS
EFIAPI
LibCredentialGetAuthInfo(
    IN EDKII_REDFISH_CREDENTIAL_PROTOCOL *This,
    OUT EDKII_REDFISH_AUTH_METHOD *AuthMethod, OUT CHAR8 **UserId,
    OUT CHAR8 **Password)
{
  EFI_STATUS Status;

  if ((This == NULL) || (AuthMethod == NULL) || (UserId == NULL) ||
      (Password == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  if (mStopRedfishService) {
    return EFI_ACCESS_DENIED;
  }

  Status = GetRedfishCredential(AuthMethod, UserId, Password);

  return Status;
}

/**
  Notify the Redfish service to stop provide configuration service to this
platform.

  This function should be called when the platfrom is about to leave the safe
environment. It will notify the Redfish service provider to abort all logined
session, and prohibit further login with original auth info. GetAuthInfo() will
return EFI_UNSUPPORTED once this function is returned.

  @param[in]   This                Pointer to EDKII_REDFISH_CREDENTIAL_PROTOCOL
instance.
  @param[in]   ServiceStopType     Reason of stopping Redfish service.

  @retval EFI_SUCCESS              Service has been stoped successfully.
  @retval EFI_INVALID_PARAMETER    This is NULL or given the worng
ServiceStopType.
  @retval EFI_UNSUPPORTED          Not support to stop Redfish service.
  @retval Others                   Some error happened.

**/
EFI_STATUS
EFIAPI
LibStopRedfishService(
    IN EDKII_REDFISH_CREDENTIAL_PROTOCOL         *This,
    IN EDKII_REDFISH_CREDENTIAL_STOP_SERVICE_TYPE ServiceStopType)
{
  if (ServiceStopType >= ServiceStopTypeMax) {
    return EFI_INVALID_PARAMETER;
  }

  // For Raspberry Pi, we don't halt on secure boot or exit boot service
  // Simply mark the service as stopped for the given reason
  mStopRedfishService = TRUE;
  DEBUG(
      (DEBUG_INFO, "EFI Redfish service is stopped (type: %d)\n",
       ServiceStopType));

  return EFI_SUCCESS;
}

/**
  Notification of Exit Boot Service.

  @param[in]  This    Pointer to EDKII_REDFISH_CREDENTIAL_PROTOCOL.
**/
VOID EFIAPI
LibCredentialExitBootServicesNotify(IN EDKII_REDFISH_CREDENTIAL_PROTOCOL *This)
{
}

/**
  Notification of End of DXE.

  @param[in]  This    Pointer to EDKII_REDFISH_CREDENTIAL_PROTOCOL.
**/
VOID EFIAPI
LibCredentialEndOfDxeNotify(IN EDKII_REDFISH_CREDENTIAL_PROTOCOL *This)
{
}

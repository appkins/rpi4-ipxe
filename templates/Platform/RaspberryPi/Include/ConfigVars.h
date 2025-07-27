/** @file
 *
 *  Copyright (c) 2020, Andrei Warkentin <andrey.warkentin@gmail.com>
 *  Copyright (c) 2020, ARM Limited. All rights reserved.
 *
 *  SPDX-License-Identifier: BSD-2-Clause-Patent
 *
 **/

#ifndef CONFIG_VARS_H
#define CONFIG_VARS_H

#pragma pack(1)
typedef struct {
  /*
   * One bit for each scaled resolution supported,
   * these are ordered exactly like mGopModeData
   * in DisplayDxe.
   *
   * 800x600, 640x480, 1024x768, 720p, 1080p, native.
   */
   UINT8 v800   : 1;
   UINT8 v640   : 1;
   UINT8 v1024  : 1;
   UINT8 v720p  : 1;
   UINT8 v1080p : 1;
   UINT8 Physical : 1;
} DISPLAY_ENABLE_SCALED_VMODES_VARSTORE_DATA;
#pragma pack()

typedef struct {
  /*
   * 0 - No screenshot support.
   * 1 - Screenshot support via hotkey.
   */
   UINT32 Enable;
} DISPLAY_ENABLE_SSHOT_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - No JTAG.
   * 1 - JTAG mode.
   */
   UINT32 Enable;
} DEBUG_ENABLE_JTAG_VARSTORE_DATA;

typedef struct {
#define CHIPSET_CPU_CLOCK_LOW     0
#define CHIPSET_CPU_CLOCK_DEFAULT 1
#define CHIPSET_CPU_CLOCK_MAX     2
#define CHIPSET_CPU_CLOCK_CUSTOM  3
  UINT32 Clock;
} CHIPSET_CPU_CLOCK_VARSTORE_DATA;

typedef struct {
  UINT32 Clock;
} CHIPSET_CUSTOM_CPU_CLOCK_VARSTORE_DATA;

typedef struct {
  /*
   * Always set by ConfigDxe prior to HII init to reflect
   * platform capability.
   */
  UINT32 Supported;
} ADVANCED_RAM_MORE_THAN_3GB_VARSTORE_DATA;

typedef struct {
  UINT32 Enabled;
} ADVANCED_RAM_LIMIT_TO_3GB_VARSTORE_DATA;

typedef struct {
  UINT32 Enabled;
} ADVANCED_FAN_ON_GPIO_VARSTORE_DATA;

typedef struct {
  UINT32 Value;
} ADVANCED_FANTEMP_VARSTORE_DATA;

typedef struct {
  UINT32 Value;
} ADVANCED_XHCIPCI_VARSTORE_DATA;

typedef struct {
#define SYSTEM_TABLE_MODE_ACPI 0
#define SYSTEM_TABLE_MODE_BOTH 1
#define SYSTEM_TABLE_MODE_DT   2
  UINT32 Mode;
} SYSTEM_TABLE_MODE_VARSTORE_DATA;

#define ASSET_TAG_STR_MAX_LEN       32
#define ASSET_TAG_STR_STORAGE_SIZE  33
typedef struct {
  CHAR16 AssetTag[ASSET_TAG_STR_STORAGE_SIZE];
} ADVANCED_ASSET_TAG_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - uSD slot routed to Broadcom SDHOST on Pi 3 or eMMC2 on Pi 4.
   * 1 - uSD slot routed to Arasan SDHCI.
   */
  UINT32 Routing;
} MMC_SD_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - Don't disable multi-block.
   * 1 - Disable multi-block commands.
   */
  UINT32 DisableMulti;
} MMC_DISMULTI_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - Don't force 1 bit mode.
   * 1 - Force 1 bit mode.
   */
  UINT32 Force1Bit;
} MMC_FORCE1BIT_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - Don't force default speed.
   * 1 - Force default speed.
   */
  UINT32 ForceDS;
} MMC_FORCEDS_VARSTORE_DATA;

typedef struct {
  /*
   * Default Speed MHz override (25MHz default).
   */
  UINT32 MHz;
} MMC_SD_DS_MHZ_VARSTORE_DATA;

typedef struct {
  /*
   * High Speed MHz override (50MHz default).
   */
  UINT32 MHz;
} MMC_SD_HS_MHZ_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - eMMC PIO mode
   * 1 - eMMC DMA mode
   */
  UINT32 EnableDma;
} MMC_EMMC_DMA_VARSTORE_DATA;

//
// Redfish Service Configuration
//

#define REDFISH_IP_ADDRESS_STR_MAX_LEN     15
#define REDFISH_IP_ADDRESS_STR_STORAGE_SIZE 16
typedef struct {
  UINT8 IpAddress[REDFISH_IP_ADDRESS_STR_STORAGE_SIZE];
} REDFISH_SERVICE_IP_ADDRESS_VARSTORE_DATA;

typedef struct {
  /*
   * Redfish Service Port (default 5000)
   */
  UINT16 Port;
} REDFISH_SERVICE_IP_PORT_VARSTORE_DATA;

#define REDFISH_USERID_STR_MAX_LEN     63
#define REDFISH_USERID_STR_STORAGE_SIZE 64
typedef struct {
  UINT8 UserId[REDFISH_USERID_STR_STORAGE_SIZE];
} REDFISH_SERVICE_USERID_VARSTORE_DATA;

#define REDFISH_PASSWORD_STR_MAX_LEN     63
#define REDFISH_PASSWORD_STR_STORAGE_SIZE 64
typedef struct {
  UINT8 Password[REDFISH_PASSWORD_STR_STORAGE_SIZE];
} REDFISH_SERVICE_PASSWORD_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - Disable Redfish Authentication
   * 1 - Enable Redfish Authentication
   */
  UINT32 Enabled;
} REDFISH_AUTH_ENABLED_VARSTORE_DATA;

typedef struct {
  /*
   * 0 - Disable Redfish
   * 1 - Enable Redfish
   */
  UINT32 Enable;
} REDFISH_SERVICE_ENABLE_VARSTORE_DATA;

typedef struct {
  /*
   * IP Assignment Type:
   * 0 - Unknown
   * 1 - Static
   * 2 - DHCP
   * 3 - AutoConfig
   */
  UINT32 IpAssignmentType;
} REDFISH_SERVICE_IP_ASSIGNMENT_VARSTORE_DATA;

#endif /* CONFIG_VARS_H */

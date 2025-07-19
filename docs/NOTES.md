# Notes

## gRaspberryPiFirmwareProtocolGuid

[platforms/Platform/RaspberryPi/Include/Protocol/RpiFirmware.h]
Specifies Notify Reset needed by Redfish:
NOTIFY_XHCI_RESET

Also specifies method to obtain MAC address:
GET_MAC_ADDRESS

## [Start-Up Event to Trigger EDKII Redfish Feature Core [11]](https://github.com/tianocore/edk2-redfish-client/blob/main/RedfishClientPkg/Readme.md#start-up-event-to-trigger-edkii-redfish-feature-core-11)

This is an EFI event for triggering EDKII Redfish Feature Core to travel URIs in the database and execute the callback that registered by Redfish feature drivers. The event GUID is defined in below PCD and is default set to gEfiEventReadyToBootGuid.

`PcdEdkIIRedfishFeatureDriverStartupEventGuid`
This PCD can be overridden to any events based on the platform implementation. EDKII Redfish Feature Core can be triggered earlier, for example before the BDS or in the early DXE phase if the platform provides the EFI REST EX protocol which is available before the BDS phase.

*So* we need to set `PcdEdkIIRedfishFeatureDriverStartupEventGuid` to the RPi4 platform specific reset, which defaults to the XHCI value.

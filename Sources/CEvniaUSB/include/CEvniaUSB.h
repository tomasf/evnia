#ifndef CEVNIAUSB_H
#define CEVNIAUSB_H

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CEvniaUSBDevice *CEvniaUSBDeviceRef;

CEvniaUSBDeviceRef CEvniaUSBOpenDevice(uint16_t vendorID, uint16_t productID, IOReturn *errorCode);
void CEvniaUSBCloseDevice(CEvniaUSBDeviceRef device);
IOReturn CEvniaUSBControlTransfer(
    CEvniaUSBDeviceRef device,
    uint8_t bmRequestType,
    uint8_t bRequest,
    uint16_t wValue,
    uint16_t wIndex,
    void *data,
    uint16_t length,
    uint32_t timeoutMilliseconds,
    uint16_t *bytesTransferred
);

#ifdef __cplusplus
}
#endif

#endif

#include "CEvniaUSB.h"

#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <stdlib.h>
#include <string.h>

struct CEvniaUSBDevice {
    IOUSBDeviceInterface942 **interface;
    int isOpen;
};

static IOReturn evnia_add_match_number(CFMutableDictionaryRef dict, CFStringRef key, int value)
{
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    if (number == NULL) {
        return kIOReturnNoMemory;
    }

    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
    return kIOReturnSuccess;
}

CEvniaUSBDeviceRef CEvniaUSBOpenDevice(uint16_t vendorID, uint16_t productID, IOReturn *errorCode)
{
    io_iterator_t iterator = IO_OBJECT_NULL;
    io_service_t service = IO_OBJECT_NULL;
    IOCFPlugInInterface **plugin = NULL;
    IOUSBDeviceInterface942 **deviceInterface = NULL;
    CEvniaUSBDeviceRef device = NULL;
    CFMutableDictionaryRef matching = NULL;
    SInt32 score = 0;
    IOReturn kr = kIOReturnSuccess;
    HRESULT result = S_OK;

    if (errorCode != NULL) {
        *errorCode = kIOReturnSuccess;
    }

    matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (matching == NULL) {
        kr = kIOReturnNoMemory;
        goto cleanup;
    }

    kr = evnia_add_match_number(matching, CFSTR(kUSBVendorID), vendorID);
    if (kr != kIOReturnSuccess) goto cleanup;

    kr = evnia_add_match_number(matching, CFSTR(kUSBProductID), productID);
    if (kr != kIOReturnSuccess) goto cleanup;

    kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
    matching = NULL;
    if (kr != kIOReturnSuccess) goto cleanup;

    service = IOIteratorNext(iterator);
    if (service == IO_OBJECT_NULL) {
        kr = kIOReturnNotFound;
        goto cleanup;
    }

    kr = IOCreatePlugInInterfaceForService(
        service,
        kIOUSBDeviceUserClientTypeID,
        kIOCFPlugInInterfaceID,
        &plugin,
        &score
    );
    if (kr != kIOReturnSuccess || plugin == NULL) {
        if (kr == kIOReturnSuccess) kr = kIOReturnError;
        goto cleanup;
    }

    result = (*plugin)->QueryInterface(
        plugin,
        CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID942),
        (LPVOID *)&deviceInterface
    );
    if (result != S_OK || deviceInterface == NULL) {
        kr = (IOReturn)(result != S_OK ? result : kIOReturnError);
        goto cleanup;
    }

    device = (CEvniaUSBDeviceRef)calloc(1, sizeof(*device));
    if (device == NULL) {
        kr = kIOReturnNoMemory;
        goto cleanup;
    }

    device->interface = deviceInterface;
    deviceInterface = NULL;

    kr = (*device->interface)->USBDeviceOpenSeize(device->interface);
    if (kr != kIOReturnSuccess) {
        IOReturn openKR = (*device->interface)->USBDeviceOpen(device->interface);
        if (openKR != kIOReturnSuccess) {
            kr = openKR;
            goto cleanup;
        }
    }
    device->isOpen = 1;

cleanup:
    if (plugin != NULL) {
        IODestroyPlugInInterface(plugin);
    }
    if (service != IO_OBJECT_NULL) {
        IOObjectRelease(service);
    }
    if (iterator != IO_OBJECT_NULL) {
        IOObjectRelease(iterator);
    }
    if (matching != NULL) {
        CFRelease(matching);
    }
    if (kr != kIOReturnSuccess) {
        if (deviceInterface != NULL) {
            (*deviceInterface)->Release(deviceInterface);
        }
        if (device != NULL) {
            if (device->interface != NULL) {
                if (device->isOpen) {
                    (*device->interface)->USBDeviceClose(device->interface);
                }
                (*device->interface)->Release(device->interface);
            }
            free(device);
            device = NULL;
        }
        if (errorCode != NULL) {
            *errorCode = kr;
        }
    }

    return device;
}

void CEvniaUSBCloseDevice(CEvniaUSBDeviceRef device)
{
    if (device == NULL) {
        return;
    }

    if (device->interface != NULL) {
        if (device->isOpen) {
            (*device->interface)->USBDeviceClose(device->interface);
        }
        (*device->interface)->Release(device->interface);
    }

    free(device);
}

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
)
{
    IOUSBDevRequestTO request;
    IOReturn kr;

    if (bytesTransferred != NULL) {
        *bytesTransferred = 0;
    }
    if (device == NULL || device->interface == NULL) {
        return kIOReturnNotOpen;
    }

    memset(&request, 0, sizeof(request));
    request.bmRequestType = bmRequestType;
    request.bRequest = bRequest;
    request.wValue = wValue;
    request.wIndex = wIndex;
    request.wLength = length;
    request.pData = data;
    request.noDataTimeout = timeoutMilliseconds;
    request.completionTimeout = timeoutMilliseconds;

    kr = (*device->interface)->DeviceRequestTO(device->interface, &request);
    if (bytesTransferred != NULL) {
        *bytesTransferred = request.wLenDone;
    }
    return kr;
}

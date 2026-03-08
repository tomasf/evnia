import Foundation
import IOKit
import IOKit.usb

final class USBDeviceInterface {
    private typealias DeviceInterfacePointer = UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>
    private typealias PluginInterfacePointer = UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>

    private let vendorID: UInt16
    private let productID: UInt16
    private var deviceInterface: DeviceInterfacePointer?
    private var isOpen = false

    init(vendorID: UInt16, productID: UInt16) throws {
        self.vendorID = vendorID
        self.productID = productID
        self.deviceInterface = try Self.openDevice(vendorID: vendorID, productID: productID)
        self.isOpen = true
    }

    deinit {
        close()
    }

    func controlTransfer(
        bmRequestType: UInt8,
        bRequest: UInt8,
        wValue: UInt16,
        wIndex: UInt16,
        bytes: inout [UInt8],
        timeoutMilliseconds: UInt32,
        address: UInt16
    ) throws {
        guard let deviceInterface else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: kIOReturnNotOpen)
        }

        var request = IOUSBDevRequestTO(
            bmRequestType: bmRequestType,
            bRequest: bRequest,
            wValue: wValue,
            wIndex: wIndex,
            wLength: UInt16(bytes.count),
            pData: nil,
            wLenDone: 0,
            noDataTimeout: timeoutMilliseconds,
            completionTimeout: timeoutMilliseconds
        )

        let result = bytes.withUnsafeMutableBytes { rawBuffer -> IOReturn in
            request.pData = rawBuffer.baseAddress
            return callDeviceRequest(deviceInterface.pointee!.pointee.DeviceRequestTO, selfPointer: deviceInterface, request: &request)
        }

        guard result == kIOReturnSuccess else {
            throw EvniaError.requestFailed(address: address, code: result)
        }
        guard Int(request.wLenDone) == bytes.count else {
            throw EvniaError.shortTransfer(address: address, expected: bytes.count, actual: Int(request.wLenDone))
        }
    }

    private func close() {
        guard let deviceInterface, let interface = deviceInterface.pointee else { return }

        if isOpen {
            _ = interface.pointee.USBDeviceClose?(UnsafeMutableRawPointer(deviceInterface))
            isOpen = false
        }
        _ = interface.pointee.Release?(UnsafeMutableRawPointer(deviceInterface))
        self.deviceInterface = nil
    }

    private static func openDevice(vendorID: UInt16, productID: UInt16) throws -> DeviceInterfacePointer {
        guard let matching = IOServiceMatching(kIOUSBDeviceClassName) else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: kIOReturnNoMemory)
        }

        try addMatchNumber(to: matching, key: kUSBVendorID, value: Int(vendorID), vendorID: vendorID, productID: productID)
        try addMatchNumber(to: matching, key: kUSBProductID, value: Int(productID), vendorID: vendorID, productID: productID)

        var iterator: io_iterator_t = IO_OBJECT_NULL
        let servicesResult = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard servicesResult == kIOReturnSuccess else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: servicesResult)
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != IO_OBJECT_NULL else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: kIOReturnNotFound)
        }
        defer { IOObjectRelease(service) }

        var plugin: PluginInterfacePointer?
        var score: Int32 = 0
        let pluginResult = IOCreatePlugInInterfaceForService(
            service,
            ioUSBDeviceUserClientTypeID(),
            ioCFPlugInInterfaceID(),
            &plugin,
            &score
        )
        guard pluginResult == kIOReturnSuccess, let plugin else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: pluginResult)
        }
        defer { IODestroyPlugInInterface(plugin) }

        var rawDeviceInterface: UnsafeMutableRawPointer?
        let queryResult = plugin.pointee!.pointee.QueryInterface?(
            UnsafeMutableRawPointer(plugin),
            CFUUIDGetUUIDBytes(ioUSBDeviceInterfaceID942()),
            &rawDeviceInterface
        ) ?? HRESULT(kIOReturnUnsupported)
        guard queryResult == S_OK, let rawDeviceInterface else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: IOReturn(queryResult))
        }

        let deviceInterface = rawDeviceInterface.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBDeviceInterface942>?.self)

        let seizeResult = deviceInterface.pointee!.pointee.USBDeviceOpenSeize?(UnsafeMutableRawPointer(deviceInterface)) ?? kIOReturnUnsupported
        if seizeResult != kIOReturnSuccess {
            let openResult = deviceInterface.pointee!.pointee.USBDeviceOpen?(UnsafeMutableRawPointer(deviceInterface)) ?? kIOReturnUnsupported
            guard openResult == kIOReturnSuccess else {
                _ = deviceInterface.pointee!.pointee.Release?(UnsafeMutableRawPointer(deviceInterface))
                throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: openResult)
            }
        }

        return deviceInterface
    }

    private static func addMatchNumber(
        to dict: CFMutableDictionary,
        key: String,
        value: Int,
        vendorID: UInt16,
        productID: UInt16
    ) throws {
        var mutableValue = value
        guard let number = CFNumberCreate(kCFAllocatorDefault, .intType, &mutableValue) else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: kIOReturnNoMemory)
        }
        CFDictionarySetValue(
            dict,
            Unmanaged.passUnretained(key as CFString).toOpaque(),
            Unmanaged.passUnretained(number).toOpaque()
        )
    }
}

private func ioCFPlugInInterfaceID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
        0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F
    )
}

private func ioUSBDeviceUserClientTypeID() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        nil,
        0x9D, 0xC7, 0xB7, 0x80, 0x9E, 0xC0, 0x11, 0xD4,
        0xA5, 0x4F, 0x00, 0x0A, 0x27, 0x05, 0x28, 0x61
    )
}

private func ioUSBDeviceInterfaceID942() -> CFUUID {
    CFUUIDGetConstantUUIDWithBytes(
        kCFAllocatorSystemDefault,
        0x56, 0xAD, 0x08, 0x9D, 0x87, 0x8D, 0x4B, 0xEA,
        0xA1, 0xF5, 0x2C, 0x8D, 0xC4, 0x3E, 0x8A, 0x98
    )
}

private func callDeviceRequest(
    _ fn: (@convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<IOUSBDevRequestTO>?) -> IOReturn)?,
    selfPointer: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface942>?>,
    request: UnsafeMutablePointer<IOUSBDevRequestTO>
) -> IOReturn {
    guard let fn else { return kIOReturnUnsupported }
    return fn(UnsafeMutableRawPointer(selfPointer), request)
}

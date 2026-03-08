import Foundation

public final class EvniaLEDController {
    public static let vendorID: UInt16 = 0x0CF2
    public static let productID: UInt16 = 0xB201
    public static let ledCount = 44

    private static let requestTypeOut: UInt8 = 0x40
    private static let writeRequest: UInt8 = 0x80
    private static let timeoutMilliseconds: UInt32 = 2_000
    private static let controlBlockAddresses: [UInt16] = [0xE020, 0xE030]
    private static let baselineControlRegionAddress: UInt16 = 0xE020
    private static let e100Address: UInt16 = 0xE100
    private static let baselineControlRegion: [UInt8] = [
        0x00, 0x01, 0x02, 0x00, 0x00, 0x05, 0x00, 0x00,
        0x00, 0x02, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x02, 0x00, 0x00, 0x05, 0x00, 0x00,
        0x00, 0x02, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]

    private let device: USBDeviceInterface

    public init(vendorID: UInt16 = EvniaLEDController.vendorID, productID: UInt16 = EvniaLEDController.productID) throws {
        self.device = try USBDeviceInterface(vendorID: vendorID, productID: productID)
    }

    public func setCaptureEnabled(_ enabled: Bool) throws {
        if enabled {
            let block = Self.makeCaptureControlBlock()
            for address in Self.controlBlockAddresses {
                try write(address: address, bytes: block)
            }
        } else {
            try write(address: Self.baselineControlRegionAddress, bytes: Self.baselineControlRegion)
        }
    }

    public func setColors(_ colors: [RGBColor]) throws {
        guard colors.count == Self.ledCount else {
            throw EvniaError.invalidColorCount(expected: Self.ledCount, actual: colors.count)
        }
        try write(address: Self.e100Address, bytes: flatten(colors))
    }

    private func write(address: UInt16, bytes: [UInt8]) throws {
        var mutableBytes = bytes
        try device.controlTransfer(
            bmRequestType: Self.requestTypeOut,
            bRequest: Self.writeRequest,
            wValue: 0,
            wIndex: address,
            bytes: &mutableBytes,
            timeoutMilliseconds: Self.timeoutMilliseconds,
            address: address
        )
    }

    private static func makeCaptureControlBlock() -> [UInt8] {
        [
            0x01, 0x00, 0x02, 0x04,
            0x00, 0x05, 0x00, 0x00,
            0x00, 0x02, 0xFF, 0x00,
            0x00, 0x00, 0x00, 0x01,
        ]
    }
}

public struct RGBColor: Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = RGBColor(red: 0, green: 0, blue: 0)
}

public enum EvniaError: Error, CustomStringConvertible {
    case deviceOpenFailed(vendorID: UInt16, productID: UInt16, code: IOReturn)
    case invalidColorCount(expected: Int, actual: Int)
    case requestFailed(address: UInt16, code: IOReturn)
    case shortTransfer(address: UInt16, expected: Int, actual: Int)

    public var description: String {
        switch self {
        case let .deviceOpenFailed(vendorID, productID, code):
            return "Failed to open Evnia USB device \(hex(vendorID, width: 4)):\(hex(productID, width: 4)); IOReturn=\(hex(UInt32(bitPattern: code), width: 8))"
        case let .invalidColorCount(expected, actual):
            return "Expected exactly \(expected) colors, got \(actual)"
        case let .requestFailed(address, code):
            return "USB control transfer failed at register \(hex(address, width: 4)); IOReturn=\(hex(UInt32(bitPattern: code), width: 8))"
        case let .shortTransfer(address, expected, actual):
            return "Short USB write at register \(hex(address, width: 4)); expected \(expected) bytes, wrote \(actual)"
        }
    }
}

private func flatten(_ colors: [RGBColor]) -> [UInt8] {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(colors.count * 3)
    for color in colors {
        bytes.append(color.red)
        bytes.append(color.green)
        bytes.append(color.blue)
    }
    return bytes
}

private func hex<T: BinaryInteger>(_ value: T, width: Int) -> String {
    let rendered = String(value, radix: 16, uppercase: true)
    return "0x" + String(repeating: "0", count: max(0, width - rendered.count)) + rendered
}

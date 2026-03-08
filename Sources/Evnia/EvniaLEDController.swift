import CEvniaUSB
import Foundation

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

    public static func rainbow(count: Int) -> [RGBColor] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let hue = UInt16((UInt32(index) * 1536) / UInt32(count))
            return hueToRGB(hue)
        }
    }

    private static func hueToRGB(_ hue: UInt16) -> RGBColor {
        let segment = Int(hue / 256)
        let step = UInt8(hue % 256)

        switch segment {
        case 0:
            return RGBColor(red: 255, green: step, blue: 0)
        case 1:
            return RGBColor(red: 255 &- step, green: 255, blue: 0)
        case 2:
            return RGBColor(red: 0, green: 255, blue: step)
        case 3:
            return RGBColor(red: 0, green: 255 &- step, blue: 255)
        case 4:
            return RGBColor(red: step, green: 0, blue: 255)
        default:
            return RGBColor(red: 255, green: 0, blue: 255 &- step)
        }
    }
}

public enum EvniaError: Error, CustomStringConvertible {
    case deviceOpenFailed(vendorID: UInt16, productID: UInt16, code: IOReturn)
    case invalidColorCount(expected: Int, actual: Int)
    case captureDisableUnsupported
    case requestFailed(address: UInt16, code: IOReturn)
    case shortTransfer(address: UInt16, expected: Int, actual: Int)

    public var description: String {
        switch self {
        case let .deviceOpenFailed(vendorID, productID, code):
            return "Failed to open Evnia USB device \(hex(vendorID, width: 4)):\(hex(productID, width: 4)); IOReturn=\(hex(UInt32(bitPattern: code), width: 8))"
        case let .invalidColorCount(expected, actual):
            return "Expected exactly \(expected) colors, got \(actual)"
        case .captureDisableUnsupported:
            return "Disabling software capture is not reverse-engineered yet; the current USB path can enable and drive the LED frame, but not reliably hand control back to the monitor OSD"
        case let .requestFailed(address, code):
            return "USB control transfer failed at register \(hex(address, width: 4)); IOReturn=\(hex(UInt32(bitPattern: code), width: 8))"
        case let .shortTransfer(address, expected, actual):
            return "Short USB write at register \(hex(address, width: 4)); expected \(expected) bytes, wrote \(actual)"
        }
    }
}

public final class EvniaLEDController {
    public static let vendorID: UInt16 = 0x0CF2
    public static let productID: UInt16 = 0xB201
    public static let ledCount = 44

    private static let requestTypeOut: UInt8 = 0x40
    private static let writeRequest: UInt8 = 0x80
    private static let timeoutMilliseconds: UInt32 = 2_000
    private static let controlBlockAddresses: [UInt16] = [0xE020, 0xE030]
    private static let e100Address: UInt16 = 0xE100

    private var device: CEvniaUSBDeviceRef?

    public init(vendorID: UInt16 = EvniaLEDController.vendorID, productID: UInt16 = EvniaLEDController.productID) throws {
        var errorCode: IOReturn = kIOReturnSuccess
        let opened = CEvniaUSBOpenDevice(vendorID, productID, &errorCode)
        guard let opened else {
            throw EvniaError.deviceOpenFailed(vendorID: vendorID, productID: productID, code: errorCode)
        }
        device = opened
    }

    deinit {
        if let device {
            CEvniaUSBCloseDevice(device)
        }
    }

    public func setCaptureEnabled(_ enabled: Bool) throws {
        guard enabled else {
            throw EvniaError.captureDisableUnsupported
        }

        let block = Self.makeControlBlock(captureEnabled: enabled)
        for address in Self.controlBlockAddresses {
            try write(address: address, bytes: block)
        }
    }

    public func setColors(_ colors: [RGBColor]) throws {
        try apply(captureEnabled: true, colors: colors)
    }

    public func apply(captureEnabled: Bool, colors: [RGBColor]) throws {
        guard colors.count == Self.ledCount else {
            throw EvniaError.invalidColorCount(expected: Self.ledCount, actual: colors.count)
        }

        guard captureEnabled else {
            throw EvniaError.captureDisableUnsupported
        }

        try setCaptureEnabled(captureEnabled)
        try write(address: Self.e100Address, bytes: flatten(colors))
    }

    private func write(address: UInt16, bytes: [UInt8]) throws {
        guard let device else {
            throw EvniaError.deviceOpenFailed(vendorID: Self.vendorID, productID: Self.productID, code: kIOReturnNotOpen)
        }

        var mutableBytes = bytes
        let length = UInt16(mutableBytes.count)
        var transferred: UInt16 = 0
        let result = mutableBytes.withUnsafeMutableBytes { rawBuffer -> IOReturn in
            CEvniaUSBControlTransfer(
                device,
                Self.requestTypeOut,
                Self.writeRequest,
                0,
                address,
                rawBuffer.baseAddress,
                length,
                Self.timeoutMilliseconds,
                &transferred
            )
        }

        guard result == kIOReturnSuccess else {
            throw EvniaError.requestFailed(address: address, code: result)
        }
        guard Int(transferred) == bytes.count else {
            throw EvniaError.shortTransfer(address: address, expected: bytes.count, actual: Int(transferred))
        }
    }

    private static func makeControlBlock(captureEnabled: Bool) -> [UInt8] {
        var block: [UInt8] = [
            0x01, 0x00, 0x02, 0x04,
            0x00, 0x05, 0x00, 0x00,
            0x00, 0x02, 0xFF, 0x00,
            0x00, 0x00, 0x00, 0x01,
        ]

        // This bit is treated as the current software-capture toggle.
        block[15] = captureEnabled ? 0x01 : 0x00
        return block
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
    let padded = String(repeating: "0", count: max(0, width - rendered.count)) + rendered
    return "0x\(padded)"
}

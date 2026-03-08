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
    public static let white = RGBColor(red: 255, green: 255, blue: 255)
    public static let red = RGBColor(red: 255, green: 0, blue: 0)
    public static let green = RGBColor(red: 0, green: 255, blue: 0)
    public static let blue = RGBColor(red: 0, green: 0, blue: 255)
    public static let yellow = RGBColor(red: 255, green: 255, blue: 0)
    public static let cyan = RGBColor(red: 0, green: 255, blue: 255)
    public static let magenta = RGBColor(red: 255, green: 0, blue: 255)
}

public struct LEDFrame: Equatable, Sendable {
    public static let count = EvniaLEDController.ledCount

    internal var storage: [RGBColor]

    public init(color: RGBColor = .black) {
        self.storage = Array(repeating: color, count: Self.count)
    }

    public init(colors: [RGBColor]) {
        assert(colors.count == Self.count, "LEDFrame requires exactly \(Self.count) colors")
        self.storage = colors
    }

    public subscript(index: Int) -> RGBColor {
        get {
            precondition((0..<Self.count).contains(index), "LED index out of range")
            return storage[index]
        }
        set {
            precondition((0..<Self.count).contains(index), "LED index out of range")
            storage[index] = newValue
        }
    }

    internal var bytes: [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Self.count * 3)
        for color in storage {
            bytes.append(color.red)
            bytes.append(color.green)
            bytes.append(color.blue)
        }
        return bytes
    }

    public func shifted(by shift: Int) -> Self {
        var values = storage
        if shift > 0 {
            for _ in 0..<shift {
                values.insert(values.removeLast(), at: 0)
            }
        } else {
            for _ in 0..<(-shift) {
                values.append(values.removeFirst())
            }
        }
        return Self(colors: values)
    }
}

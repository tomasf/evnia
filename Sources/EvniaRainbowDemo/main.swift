import Evnia
import Foundation

do {
    let controller = try EvniaLEDController()
    try controller.setCaptureEnabled(true)
    defer { try? controller.setCaptureEnabled(false) }

    var frame = LEDFrame.rainbow
    let timeout = Date().addingTimeInterval(30)
    while Date() < timeout {
        try controller.setColors(frame)
        frame = frame.shifted(by: 1)
        Thread.sleep(forTimeInterval: 0.01)
    }
} catch {
    print("Rainbow demo failed: \(error)")
}

extension LEDFrame {
    public static var rainbow: Self {
        return Self(colors: (0..<Self.count).map {
            RGBColor(hue: UInt16(($0 * 1536) / Self.count))
        })
    }
}

extension RGBColor {
    init(hue: UInt16) {
        let step = UInt8(hue % 256)

        self = switch Int(hue / 256) {
        case 0: RGBColor(red: 255, green: step, blue: 0)
        case 1: RGBColor(red: 255 &- step, green: 255, blue: 0)
        case 2: RGBColor(red: 0, green: 255, blue: step)
        case 3: RGBColor(red: 0, green: 255 &- step, blue: 255)
        case 4: RGBColor(red: step, green: 0, blue: 255)
        default: RGBColor(red: 255, green: 0, blue: 255 &- step)
        }
    }
}

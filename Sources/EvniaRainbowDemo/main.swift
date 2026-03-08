import Evnia
import Foundation

do {
    let controller = try EvniaLEDController()
    try controller.setCaptureEnabled(true)

    let allBlack = [RGBColor](repeating: .black, count: EvniaLEDController.ledCount)

    //var colors = RGBColor.rainbow(count: EvniaLEDController.ledCount)
    let timeout = Date().addingTimeInterval(10)
    var i = 0
    while Date() < timeout {
        var colors = allBlack
        colors[i % EvniaLEDController.ledCount] = RGBColor(red: 255, green: 0, blue: 0)
        try controller.setColors(colors)
        i += 1
    }
    print("Set \(i) times = \(i / 10) FPS")
    try controller.setCaptureEnabled(false)
} catch {
    print("Rainbow demo failed: \(error)")
}


extension RGBColor {
    public static func rainbow(count: Int) -> [RGBColor] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let hue = UInt16((UInt32(index) * 1536) / UInt32(count))
            return hueToRGB(hue)
        }
    }

    private static func hueToRGB(_ hue: UInt16) -> RGBColor {
        let step = UInt8(hue % 256)

        return switch Int(hue / 256) {
        case 0: RGBColor(red: 255, green: step, blue: 0)
        case 1: RGBColor(red: 255 &- step, green: 255, blue: 0)
        case 2: RGBColor(red: 0, green: 255, blue: step)
        case 3: RGBColor(red: 0, green: 255 &- step, blue: 255)
        case 4: RGBColor(red: step, green: 0, blue: 255)
        default: RGBColor(red: 255, green: 0, blue: 255 &- step)
        }
    }
}

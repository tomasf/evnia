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

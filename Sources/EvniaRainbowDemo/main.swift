import Evnia
import Foundation

do {
    let controller = try EvniaLEDController()
    let colors = RGBColor.rainbow(count: EvniaLEDController.ledCount)
    try controller.apply(captureEnabled: true, colors: colors)
    print("Applied rainbow to \(colors.count) LEDs.")
    try controller.setCaptureEnabled(false)
} catch {
    print("EvniaRainbowDemo failed: \(error)")
}

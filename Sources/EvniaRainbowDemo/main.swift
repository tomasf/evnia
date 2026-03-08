import Evnia
import Foundation

@main
struct EvniaRainbowDemo {
    static func main() {
        do {
            let controller = try EvniaLEDController()
            let colors = RGBColor.rainbow(count: EvniaLEDController.ledCount)
            try controller.apply(captureEnabled: true, colors: colors)
            print("Applied rainbow to \(colors.count) LEDs.")
        } catch {
            fputs("EvniaRainbowDemo failed: \(error)\n", stderr)
            exit(1)
        }
    }
}

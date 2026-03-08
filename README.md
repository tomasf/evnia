# Evnia

Native macOS Swift library for controlling the Ambiglow LEDs on the Philips Evnia 49M2C8900.

This repository also documents the USB protocol that was reverse-engineered to make that work.

## Status

Confirmed working on macOS for:
- monitor: `PHL49M2C8900`
- LED controller: ENE KB7730
- USB IDs: VID `0x0CF2`, PID `0xB201`

Confirmed working features:
- take software ownership of the LEDs
- push a full 44-LED RGB frame
- release ownership back to the monitor OSD

The current Swift API is intentionally small:

```swift
let controller = try EvniaLEDController()
try controller.setCaptureEnabled(true)
try controller.setColors(frame)    // LEDFrame owns exactly 44 slots
try controller.setCaptureEnabled(false)
```

## Library Layout

- `Sources/Evnia/EvniaLEDController.swift`: high-level API
- `Sources/Evnia/USBDeviceInterface.swift`: low-level USB control-transfer wrapper using `IOKit` and `IOKit.usb`
- `Sources/EvniaRainbowDemo/main.swift`: demo executable

## Protocol Summary

The working path uses vendor-specific USB control transfers on endpoint 0.

### Transport

Read:
- `bmRequestType = 0xC0`
- `bRequest = 0x81`
- `wValue = 0x0000`
- `wIndex = register address`

Write:
- `bmRequestType = 0x40`
- `bRequest = 0x80`
- `wValue = 0x0000`
- `wIndex = register address`

This is the only confirmed useful namespace for this monitor on macOS.

Example:
- write register `0xE100` -> `0x40 / 0x80 / 0x0000 / 0xE100`
- read register `0xE020` -> `0xC0 / 0x81 / 0x0000 / 0xE020`

## Working Register Model

The practical working LED path is in the app-layer `0xE***` register family.

### Capture / software ownership

To take ownership from the monitor and allow USB-driven frames, write this 16-byte control block to both `0xE020` and `0xE030`:

```text
01 00 02 04 00 05 00 00 00 02 FF 00 00 00 00 01
```

Interpretation of the important bytes:
- byte `0` = enabled / active app control mode
- byte `1` = software mode `0` (`Normal`)
- byte `2` = speed `2` (`Low`)
- byte `3` = brightness `4` (`Bright`)
- byte `5` = device selection `5` (`AllZone`)

In practice, the capture sequence is:
1. write the block to `0xE020..0xE02F`
2. write the same block to `0xE030..0xE03F`

### Frame buffer

The LED RGB frame is a flat per-slot table at `0xE100`.

For this monitor:
- LED count = `44`
- bytes per LED = `3` (`R G B`)
- frame size = `132` bytes
- frame range = `0xE100..0xE183`

Frame layout:

```text
slot 0  -> E100 E101 E102
slot 1  -> E103 E104 E105
slot 2  -> E106 E107 E108
...
slot 43 -> E181 E182 E183
```

Each slot is written as raw `R G B` bytes.

### Release / return ownership to OSD

The confirmed release path is not a one-byte toggle. The working release sequence is to restore the baseline 64-byte control region at `0xE020..0xE05F` in one sequential write:

```text
00 01 02 00 00 05 00 00 00 02 FF 00 00 00 00 00
00 00 02 00 00 05 00 00 00 02 FF 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 FF 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

That is the sequence behind `setCaptureEnabled(false)`.

## LED Slot Mapping

The `E100` frame is ordered and directly rendered. The current physical mapping for the 49M2C8900 is:

- `0..3`: right-side vertical LEDs, with `0` at the bottom and `3` at the top-right corner
- `3..11`: top row on the right side of the center break
- `12..20`: top row on the left side of the center break
- `20..23`: left-side vertical LEDs, including the top-left corner overlap
- `24..34`: upper diffused center column above the monitor mount
- `35..43`: lower diffused center column below the mount

Notes:
- slot `0` is the furthest-right bottom LED
- slot `43` is near the bottom end of the diffused center section
- some boundary LEDs, especially around `20` and `23/24`, may behave a little strangely due to corner overlap or diffuser bleed

## Example Frame Write

To make the entire monitor solid red:

1. enable capture by patching `E020` and `E030`
2. write 132 bytes of repeating `FF 00 00` to `0xE100`

Conceptually:

```text
E020 <- capture block
E030 <- capture block
E100 <- [FF 00 00] * 44
```

## Notes For Reverse-Engineering Similar Models

If you are working on another Philips / Evnia display with an ENE controller, the best starting points are:

1. Look for a vendor-class USB device, not just HID.
2. Test EP0 control transfers with:
   - read: `0xC0 / 0x81 / 0x0000 / addr`
   - write: `0x40 / 0x80 / 0x0000 / addr`
3. Search for an app-layer register family in the `0xE***` range.
4. Look for:
   - small control blocks around `E020/E030`
   - a contiguous RGB table like `E100 + index * 3`
   - a baseline control-region restore path for release back to OSD
5. Do not assume the HID path is the real lighting path just because it is easy to enumerate.

Also note:
- the monitor OSD does not appear to update this USB-visible register space directly
- OSD likely talks to the controller over a separate internal bus
- release back to OSD may require restoring a full control-state region, not just clearing a frame buffer

## API Example

```swift
import Evnia

let controller = try EvniaLEDController()

var frame = LEDFrame()
for index in 0..<LEDFrame.ledCount {
    frame[index] = RGBColor(red: 255, green: 0, blue: 0)
}

try controller.setCaptureEnabled(true)
try controller.setColors(frame)

// later
try controller.setCaptureEnabled(false)
```

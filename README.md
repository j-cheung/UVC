# UVC

Development code for working with UVC compliant webcams.

Currently all available controls are modelled as integers.

Your frontend must know how to deal with them.

For now.

Error checking is basically non existent.

 
```swift

import Foundation
import UVC

let uvc = UVC()

let cameras = uvc.enumerateDevices()
print( cameras.map { $0.properties as CFDictionary } )

let camera = cameras[0]

let controls = uvc.getCameraControls ( camera: camera )

for control in controls {
  debugPrint(control)
}

// set white balance auto on
if let white_bal_auto = controls.first(where: { $0.uvcfamily == .processing && $0.selector.index == 0x0b }) {
  white_bal_auto.set(value: 1)
}

// set brightness to -12
if let brightness = controls.first(where: { $0.uvcfamily == .processing && $0.selector.index == 0x02 }) {
  brightness.set(value: -12)
}
```

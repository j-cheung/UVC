# UVC

Under Development code for working with UVC compliant webcams in swift.

USB via IOKit and its *lovely* **COM** implementation. 

The only controls currently implemented are the ones I have to test, see below for list output.

All controls are modeled as Int at the interface, they are properly signed, so
e.g. we can set brightness to -12 and not have to worry about it, conversion to and from
various widths of UInt and Int is done under the hood. You can't crash it by trying to set
a an underlying UInt8 control to -32,768 because it will clamp the range to 0.

Your front end code will need to know that, e.g. Auto controls are a bool, Powerline Frequency is an option or 
that Auto Exposure mode is a bitmap, and translate them to and from Int accordingly.

You probably can cause problems by setting values outside of the control's GET_MIN and GET_MAX
values, but these should theoretically just cause pipe stall errors, which you aren't going to see
because at the moment, error checking isn't really a thing.

This is just bare bones, get up and running swift code for messing with UVC.

 
```swift

import Foundation
import UVC

let uvc = UVC()

let cameras = uvc.enumerateDevices()
print( cameras.map { $0.properties as CFDictionary } )

let camera = cameras[0]

/*
  this will give you a list of the selectors of all the controls on *your* particular
  camera, some of which may be missing from the control cnstuction enumeration
  I will probably add the rest soon.
*/
let pucontrols = uvc.enumerateControls(uvc: camera, target: camera.punitID, range: 0x01...0x13 )
let itcontrols = uvc.enumerateControls(uvc: camera, target: camera.itermID, range: 0x01...0x14 )
print(pucontrols)
print(itcontrols)

/*
  this enumeration will only return controls that I have implemented the map for in
  the UVC constructIntegerControl functions (see UVC.swift)
 */
let controls = uvc.getCameraControls ( camera: camera )

for control in controls {
  debugPrint(control)
}

// set white balance auto on
if let white_bal_auto = controls.first(where: { $0.tag == .white_bal_temp_auto }) {
  white_bal_auto.set(value: 1)
}

// set brightness
if let brightness = controls.first(where: { $0.tag == .brightness }) {
  brightness.set(value: 0)
}


/*

[{
    AppleUSBAlternateServiceRegistryID = 4294968143;
    "Built-In" = 0;
    "Bus Power Available" = 250;
    "Device Speed" = 2;
    IOCFPlugInTypes =     {
        "9dc7b780-9ec0-11d4-a54f-000a27052861" = "IOUSBHostFamily.kext/Contents/PlugIns/IOUSBLib.bundle";
    };
    IOClassNameOverride = IOUSBDevice;
    IOGeneralInterest = "IOCommand is not serializable";
    IOPowerManagement =     {
        CapabilityFlags = 65536;
        CurrentPowerState = 3;
        DevicePowerState = 2;
        DriverPowerState = 3;
        MaxPowerState = 4;
    };
    PortNum = 1;
    "USB Address" = 3;
    "USB Product Name" = "HD USB Camera";
    "USB Vendor Name" = "HD USB Camera";
    bDeviceClass = 239;
    bDeviceProtocol = 1;
    bDeviceSubClass = 2;
    bMaxPacketSize0 = 64;
    bNumConfigurations = 1;
    bcdDevice = 256;
    bcdUSB = 512;
    iManufacturer = 2;
    iProduct = 1;
    iSerialNumber = 0;
    idProduct = 37424;
    idVendor = 13028;
    kUSBCurrentConfiguration = 1;
    kUSBProductString = "HD USB Camera";
    kUSBVendorString = "HD USB Camera";
    locationID = 336592896;
    "non-removable" = no;
    sessionID = 1826016032;
}]
[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
[2, 3, 4]
-> Backlight Compensation 
fam: camera, index: 01, type: int 
resolution: 1 min:  0, max: 2, default: 1, current: 1 
inf : 00000011

-> Brightness 
fam: camera, index: 02, type: int 
resolution: 1 min:  -64, max: 64, default: 0, current: 0 
inf : 00000011

-> Contrast 
fam: camera, index: 03, type: int 
resolution: 1 min:  0, max: 64, default: 32, current: 32 
inf : 00000011

-> Gain 
fam: camera, index: 04, type: int 
resolution: 1 min:  0, max: 100, default: 0, current: 0 
inf : 00000011

-> Powerline Frequency 
fam: camera, index: 05, type: option 
resolution: 1 min:  0, max: 2, default: 1, current: 1 
inf : 00000011

-> Hue 
fam: camera, index: 06, type: int 
resolution: 1 min:  -40, max: 40, default: 0, current: 0 
inf : 00000011

-> Saturation 
fam: camera, index: 07, type: int 
resolution: 1 min:  0, max: 128, default: 60, current: 60 
inf : 00000011

-> Sharpness 
fam: camera, index: 08, type: int 
resolution: 1 min:  0, max: 6, default: 2, current: 2 
inf : 00000011

-> Gamma 
fam: camera, index: 09, type: int 
resolution: 1 min:  72, max: 500, default: 100, current: 100 
inf : 00000011

-> White Balance Temp 
fam: camera, index: 0a, type: int 
resolution: 1 min:  2800, max: 6500, default: 4600, current: 3604 
inf : 00001111

-> White Bal Temp Auto 
fam: camera, index: 0b, type: bool 
resolution: _ min:  _, max: _, default: 1, current: 1 
inf : 00000011

-> AE Mode 
fam: camera, index: 02, type: bitmap 
resolution: 9 min:  _, max: _, default: 8, current: 8 
inf : 00000011

-> AE Priorty 
fam: camera, index: 03, type: bool 
resolution: _ min:  _, max: _, default: _, current: 1 
inf : 00000011

-> Exposure Time 
fam: camera, index: 04, type: int 
resolution: 1 min:  1, max: 5000, default: 157, current: 376 
inf : 00001111
*/
```

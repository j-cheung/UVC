import Foundation

import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.USBSpec


/*
  OK, IOKit, see https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/USBBook/USBDeviceInterfaces/USBDevInterfaces.html#//apple_ref/doc/uid/TP40002645-TPXREF107
  assuming it still exists.
 
  Most notoriously, IOKit uses a COM type mechanism only with IOCFPlugInInterface instead of IUnkown
  if we want an instance of anything, we have to ask for it by UUID via an instance of IOCFPlugInInterface
  If you were sane, you would just use libUSB for this stuff, but then, if you were sane you wouldn't
  be crawling random github repos at oh my god o'clock on a school night, now would you?
*/

public struct USB {

  /*
    To do anything with a USB device, we nedd to get an interface to it.
    Most lkely, after that we also need to get an interface to an interafce (because COM)
    So. 2 tyoes of interafce, the device interafce and the interacce interface, m'kay?
   
    To get either we always have to do the plugin thing first, like COM IUnkown, then get an iface,
    we can use generics here because honestly the pointer could be to literally anything.
    Unsafe, says it right there on the tin.
   
    Anyway, lets get interafces, QueryParams is defined in usbtypes.swift and contains two
    static properties, one for device and one for interface
  */
  public func queryInterface<T> ( _ params: QueryParams<T>, for object: io_object_t ) -> COMObject<T>? {
    
    var pluginptr: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
    var score    : Int32 = 0
    
    // first we create the plugin, thats the easy bit
    IOCreatePlugInInterfaceForService ( object, params.plug, kIOCFPlugInInterfaceID, &pluginptr, &score )
    
    guard let plugin = pluginptr?.pointee?.pointee else { return nil }
    
    // the type for our interface is actually UnsafeMutablePointer<UnsafeMutablePointer<T>,
    // like this, which would be fine, but
    var comptr: UnsafeMutablePointer<UnsafeMutablePointer<T>?>?
    
    // the Quryinterface method requires Optional<LPVOID> because it's typless, and the only
    // thing it know is the UUID, wo we have to cast it to Optional<LPVOID>, but only temporarily
    // because if we just go ahead and rebind it, further access to the orig is undefined.
    // and no one wants demons in their nose. so
    
    // grab a pointer, we ignore the return because the pointee will be nil anyway
    _ = withUnsafeMutablePointer ( to: &comptr ) { comptrptr -> kern_return_t in
      
      // rebind (cast) our ***<T> to the requisite type
      comptrptr.withMemoryRebound ( to: Optional<LPVOID>.self, capacity: 1 ) { lpvoid -> kern_return_t in
        // now do the call
        plugin.QueryInterface (
          pluginptr,
          CFUUIDGetUUIDBytes ( params.iface ),
          lpvoid
        )
      }
    }
    /*
      notice this pattern : plugin.QueryInterface(pluginPtr ...
      thing.instance.Method(thing.pointer, ...) is basically how all of these work
      the methods are #defined as function pointers on the IOKit structs. fun!
    */
    
    if let instance = comptr?.pointee?.pointee { return COMObject<T> ( pointer: comptr, instance: instance ) }
    
    return nil
  }

  /*
    There is a common pattern in SO and Apple sample code where we open a device interface and query
    its properties individually like cavemen. Don't do that. Do this instead. The IORegistry already
    knows them because it enumerated them when the device was plugged in or at startup.
  */
  public func properties(of object: io_object_t) -> [String : Any] {
    
    var result : Unmanaged<CFMutableDictionary>?
    let kret   = IORegistryEntryCreateCFProperties(object, &result, kCFAllocatorDefault, 0)

    return kret == KERN_SUCCESS ? result?.takeRetainedValue() as? Dictionary<String,Any> ?? [:]
                                : [:]
  }




  /*
    IOKIt calls the bits of device drivers that poke out into the real world "services",
    given a matching dictionary (see docs linked above) we create a service iterator
    that will list them for us based on a search pattern.
   
    IOIterator happens a lot. Basically an opaque handle that we can fling back at the system
    to get ... things.
   
    This is basically a convenience for the below and I actually can't recall why I split themm out
  */
  func getServicesIterator ( matching: [String: Any] ) -> IOIterator? {
    
    var iterator = IO_OBJECT_NULL
    let kret     = IOServiceGetMatchingServices(kIOMasterPortDefault, matching as CFDictionary, &iterator)
    
    return kret == KERN_SUCCESS ? IOIterator(iterator)
                                : nil
  }
    

  /*
    based on our matching dictionary (see docs linked above and call site), get a list
    of devices
  */
  public func enumerate ( matching: [String: Any] ) -> [io_object_t] {
    
    var possibles : [io_object_t]  = []
    
    if let iterator = getServicesIterator( matching: matching ) {
      while let device = iterator.next() {
        possibles.append(device)
      }
    }
    
    return possibles
  }


  /*
    convenience wrapper around IOUSBFindInterfaceRequest so we dont have to type kIOUSBFindInterfaceDontCare how
    ever many tines we don't care, which makes it feel like we really care.
  */
  public static func findInterfaceRequest ( iclass: UInt16 = UInt16(kIOUSBFindInterfaceDontCare), isub: UInt16 = UInt16(kIOUSBFindInterfaceDontCare), iproto: UInt16 = UInt16(kIOUSBFindInterfaceDontCare), ialt: UInt16 = UInt16(kIOUSBFindInterfaceDontCare) ) -> IOUSBFindInterfaceRequest {
    
    IOUSBFindInterfaceRequest(
        bInterfaceClass   : UInt16(iclass),
        bInterfaceSubClass: UInt16(isub),
        bInterfaceProtocol: UInt16(iproto),
        bAlternateSetting : UInt16(ialt)
    )
  }


  
  // OH THANK GOD! been looking for one of these for ages!
  // https://stackoverflow.com/questions/3887309/mapping-iokit-ioreturn-error-code-to-string
  public static func machErrorDescription (_ kr: kern_return_t) -> String {
    if let cStr = mach_error_string(kr) {
      return String (cString: cStr)
    }
    else {
      return "Unknown kernel error \(kr)"
    }
  }
  
  /*
   #defined as macro in C header so not imported
   bmRequest field of control requests is a bitmap field and thus a fucker to construct
   this helps
  */
  public static func makebmRequestType(direction: Int, type: Int, recipient: Int) -> UInt8 {
      return UInt8((direction & kUSBRqDirnMask) << kUSBRqDirnShift) |
             UInt8((type & kUSBRqTypeMask) << kUSBRqTypeShift)|UInt8(recipient & kUSBRqRecipientMask)

  }
  
}




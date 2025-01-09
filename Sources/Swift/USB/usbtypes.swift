

import Foundation



extension USB {
  
  /*
    IOKit uses COM, but we are importing the C interface, so we call like instance.Method( self_pointer,  ...)
    these are basically function pointers and will work on any old instance but either way, we usually
    need these together
  */

  public struct COMObject<T> {
    internal let pointer  : UnsafeMutablePointer<UnsafeMutablePointer<T>?>?
    internal let instance : T
  }

  

  /*
    when we call queryInterface, we need 3 params, one of which is a type,
    we can derive the other two from either one, there may be others
    this gives us a nice dot notation at the call site
  */

  public struct QueryParams<T> {
    
    let plug  : CFUUID
    let iface : CFUUID
    
    static var device    : QueryParams<IOUSBDeviceInterface>    { QueryParams<IOUSBDeviceInterface>    (plug: kIOUSBDeviceUserClientTypeID,    iface: kIOUSBDeviceInterfaceID) }
    static var interface : QueryParams<IOUSBInterfaceInterface> { QueryParams<IOUSBInterfaceInterface> (plug: kIOUSBInterfaceUserClientTypeID, iface: kIOUSBInterfaceInterfaceID) }
  }
  
}

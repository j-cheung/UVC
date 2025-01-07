

import Foundation

extension USB {
  
  /*
    IOKit uses COM, but we are importing the C interface, so we call like instance.Method( self_pointer,  ...)
    these are basically function pointers and will work on any old instance but either way, we usually need these together
    this ic C based OOP, not C++
  */

  public struct COMObject<T> {
    internal let pointer  : UnsafeMutablePointer<UnsafeMutablePointer<T>?>?
    internal let instance : T
  }

  

  /*
    when we call queryInterface, we need 3 params, one of which is a type,
    we cpould derive the other two from either one, there may be others
    this gives us a nice dot notation at the call site
  */

  public struct QueryParams<T> {
    
    let plug  : CFUUID
    let iface : CFUUID
    
    static var device    : QueryParams<IOUSBDeviceInterface>    { QueryParams<IOUSBDeviceInterface>    (plug: kIOUSBDeviceUserClientTypeID,    iface: kIOUSBDeviceInterfaceID) }
    static var interface : QueryParams<IOUSBInterfaceInterface> { QueryParams<IOUSBInterfaceInterface> (plug: kIOUSBInterfaceUserClientTypeID, iface: kIOUSBInterfaceInterfaceID) }
  }
  

  /*
    written to avoid an aesthetically unpleasing pattern,
    probably unwise, but we'll see
  */

  struct IOIterator {
    
    let iterator : io_iterator_t

    init(_ iterator: io_iterator_t) { self.iterator = iterator }

    func next() -> io_object_t? {
      let object = IOIteratorNext(iterator)
      defer {
        if object == IO_OBJECT_NULL {
          IOObjectRelease(iterator)
        }
      }
      return object == IO_OBJECT_NULL ? nil : object
    }

  }
}

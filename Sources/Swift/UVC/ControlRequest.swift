
import Foundation

extension UVC {
  
  
  //TODO: error percolation
  
  public struct ControlRequestInterface {
    
    let usb : USB.COMObject<IOUSBInterfaceInterface>
    
    
    public init (usb: USB.COMObject<IOUSBInterfaceInterface> ) {
      self.usb = usb
    }
    
    /*
      OK, this could do with some exposition, if only so I don't forget.
     
      Everything is an Int if you squint. By which I mean that all the vaues we will get
      and set are just a bunch of numbers. Some of them (brightness and hue) are signed.
      The vast majority are 1 or 2 bytes though there's a couple of 4s, an 8, a 10 and a 12.
      
      They break down into a few distinct types which are int, bool, option, bitmap and multi byte.
        int:       : 1 ... n | -1 ... n
        bool       : 1 or 0
        option     : 1 .. n
        bitmap     : 11001100 indicating options set
        multi byte : multiple values in a series of bytes/words
     
      the first four of these lend themselves to easy representation in a suitably sized Int,
      only 2 are signed, both Int16, none of them are larger than an Int32 (in fact only one,
      Exposure Time Absolute) is even that big. Even the multi byte 8 and 12 will fit into
      Int64 (== Int) and Int128. Honestly the only reason not to just have Int128 and be done
      is that it feels inelegant. (edit to add : and also, swift doesn't actually expose 128 bit
      integer types in the API even though it has them, hmm)
     
      I'll add proper multi byte support later and these will redirect via the underlying mechanism,
      but for now, it goes like this :
     
      Each control type is mapped to an integer type (see uvcconsts.swift) which allows us to
      make this generic on BinaryInteger, since we know the type (and importantly, whether
      it is signed or unsigned!), we also know the size, so we can construct a typed pointer
      accordingly.
     
      As for the rest of it, UVC.RequestCode is one of 8 defined UBC requests, get, set, default,
      resolution, min, max, legth and information. UVC.Selector contains the control index and
      the class ID, either processing unit or input terminal, that contains the control.
      
    */
    
    public func inRequest<T: BinaryInteger> ( request: UVC.RequestCode, selector: UVC.Selector ) -> T? {
      
      let data = UnsafeMutablePointer<T>.allocate(capacity: 1)
      
      /*
        bmRequest is a bitmap field that sets the direction, type and destination of a USB
        control request in this case kUSBIn : host requesting from device, kUSBClass means that
        we are sending a request to a class of driver (UVC in this case) rather than say a
        device and kUSBInterface indicates we are talking to an interface (in this case the UVC
        control interface in our USB.COMObject<IOUSBInterfaceInterface>. Building these is mildly
        vexing so we use a helper.
       
        see: https://www.beyondlogic.org/usbnutshell/usb6.shtml for more detail
      */
      
      let requestType = USB.makebmRequestType(direction: kUSBIn, type: kUSBClass, recipient: kUSBInterface)

      
      var request = IOUSBDevRequest (
          bmRequestType: requestType,
          bRequest     : request.rawValue,
          wValue       : selector.index  << 8,           // wValue and wIndex are UInt16 and require the
          wIndex       : selector.target << 8,           // control index and interface subclass in their high bits
          wLength      : UInt16( MemoryLayout<T>.size ),
          pData        : data,
          wLenDone     : 0
      )

      let kr = usb.instance.ControlRequest(usb.pointer, 0, &request)
      
      if kr != 0 {
        //print( USB.machReturnDescription(kr) )
      }
      
      if request.wLenDone > 0 { return data.pointee }
      else                    { return nil          }

    }
      
    
    
    

    public func outRequest<T: BinaryInteger> ( request: UVC.RequestCode, selector: UVC.Selector, value: T ) -> T? {
      
      var value = value  // shadow otherwise it's a let const and we can't get a pointer
      
      /*
        up in our control code, because our control knows, it has passed us a concrete
        BinaryInteger of the correct type. This one is a little more involved because
        grabbing pointers to actual exisiting variables in swift requires us to be more careful
       
        withUnsafeMutablePointer allows us to do it, but it is only temporary, it is only
        permissable to use the pointer inside the closure, so we grab a pointer and do our thing.
        the closure returns a value, so we just bang the return here
        
      */
      
      return withUnsafeMutablePointer(to: &value) { data -> T? in
        
        /*
            same as above, but this time, the host is writing data to the device, hence kUSBOut
        */
        
        let requestType = USB.makebmRequestType(direction: kUSBOut, type: kUSBClass, recipient: kUSBInterface)

        
        var request = IOUSBDevRequest (
            bmRequestType: requestType,
            bRequest     : request.rawValue,
            wValue       : selector.index  << 8,
            wIndex       : selector.target << 8,
            wLength      : UInt16( MemoryLayout<T>.size ),
            pData        : data,
            wLenDone     : 0
        )

        let kr = usb.instance.ControlRequest(usb.pointer, 0, &request)
        
        if kr != 0 {
          // print( USB.machReturnDescription(kr) )
        }
        
        /*
          arguably, we don't need to return a value from here other than success/fail
          so this is modelled fairly badly, I will revisit once I add error propagation
        */
        
        if request.wLenDone > 0 { return data.pointee }
        else                    { return nil          }
      
      }
    }

  }
}

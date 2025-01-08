
import Foundation

extension UVC {
  
  
  //TODO: error percolation
  
  public struct ControlRequestInterface {
    
    let usb : USB.COMObject<IOUSBInterfaceInterface>
    
    
    public init (usb: USB.COMObject<IOUSBInterfaceInterface> ) {
      self.usb = usb
    }
    
    
    public func inRequest<T> ( request: UVC.RequestCode, selector: UVC.Selector ) -> T? {
      
      let data = UnsafeMutablePointer<T>.allocate(capacity: 1)
      
      
      let requestType = USB.makebmRequestType(direction: kUSBIn, type: kUSBClass, recipient: kUSBInterface)

      
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
        //print( USB.machErrorDescription(kr) )
      }
      
      if request.wLenDone > 0 { return data.pointee }
      else                    { return nil          }

    }
      
    
    
    

    public func outRequest<T> ( request: UVC.RequestCode, selector: UVC.Selector, value: T ) -> T? {
      
      var value = value
      
      return withUnsafeMutablePointer(to: &value) { data -> T? in
        
        
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
          //print( USB.machErrorDescription(kr) )
        }
        if request.wLenDone > 0 { return data.pointee }
        else                    { return nil          }
      
      }
    }

  }
}

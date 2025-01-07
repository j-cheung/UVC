
import Foundation
import Descriptors

/*
   common to all tyoes of controls (even the ones that dont exist yet, and probably
   won't), see below. And yes, I know we're supposed to call them ...able or what
   the fuck ever for 'pure' swift style, but I am so done with that.
*/
public protocol ControlInterface {
  var name      : String            { get }
  var selector  : UVC.Selector      { get }
  var uvctype   : UVC.ControlType   { get }
  var uvcfamily : UVC.ControlFamily { get }
}


/*
 
 used by IntegerControl<T>, to hide the fact that it is a generic,
 mainly so we can have a collection of all the subtypes of integer controls,
 which, it turns out, is basically most of them if you squint hard enough.
 see IntegerControl<T>, below
 
 (
  even the big 12 byte multibyte could be modelled as an Int128 with some padding,
  as long as your manipulation code understands how to set values, which is why we tag
  fam and selector index up here
 )
  And no, me neither with the { mutating get } but that's how you do it, as it turns out.
*/
public protocol UVCIntegerControlInterface : ControlInterface {
  
  func current() -> Int?
  func set(value: Int)
  
  var  inf       : UInt8? { mutating get }
  var  min       : Int?   { mutating get }
  var  max       : Int?   { mutating get }
  var `default`  : Int?   { mutating get }
  var resolution : Int?   { mutating get }
}



extension UVC {


  /*
    core UVC type that contains all the info and refs
    
    itd       : input terminal descriptor
    pud       : processing unit descriptor
   
    TBH we probably dont really need more of these than the unit/terminal IDs
    but they stay until I'm sure that's true.
   
    properies : duh
   
    device    : COM object for the actual device
    interface : COM object for the control interface
   
    Note the absence of the stream/bulk interface. Don't tuch that,
    that's what AVFoundation is for.
  */
  public struct Camera {
    
    // we'll keep these, just in case
    let itd        : VC_Input_Terminal_Descriptor
    let pud        : VC_Processing_Unit_Descriptor
    
    public let properties : [String: Any]
    public let device     : USB.COMObject<IOUSBDeviceInterface>
    public let interface  : USB.COMObject<IOUSBInterfaceInterface>
    
    public let punitID    : UInt16
    public let itermID    : UInt16
    
    
    init(pud : VC_Processing_Unit_Descriptor, itd: VC_Input_Terminal_Descriptor, interface: USB.COMObject<IOUSBInterfaceInterface>, device: USB.COMObject<IOUSBDeviceInterface>, properties: [String: Any] ) {
      
      self.itd        = itd
      self.pud        = pud
      self.interface  = interface
      self.device     = device
      self.properties = properties
      
      self.punitID = UInt16(pud.bUnitID)
      self.itermID = UInt16(itd.bTerminalID)
    }
    
  }

  /*
    when we send control requests, each control has a selector index specifiying the control
    and a target specifying which terminal/unit, processing or input
    unit/terminal IDs are found in the descriptors
  */
  public struct Selector {
    
    let index  : UInt16
    let target : UInt16
    
    init ( index: UInt16, target: UInt16) {
      self.index  = index
      self.target = target
    }
  }
  

  
  /*
    So you decided to model everything as an Int?
    And then you fnd out that some of them are signed?
    And that's a massive pain in the arse?
   
    Well, here you go.
   
    By making this generic on a BinaryInteger type, our pointers will always be the correct
    type and size so we we can get signed or unsigned numbers without worrying about it,
    and since the actual integer controls are no larger than Int16, we can represent ALL
    valid values in the range of an Int, the magic is transforming them for which we use
    BinaryInteger.clamping()
   
    clamping is fully generic on all BinaryInteger types, which means that it understands
    signs and widths without us having to go through the hassle of hoisting through
    various widths to preserve the sign bit.
   
    It also won't crash if we try to put 0xFFFF into a UInt8.
   
    But it also won't tell us it just stuffed 0xFF in and went on it's merry way, so be sure
    to check your control's min and max values. Are you listening future me?
   
    see the definition of .inRequest and .outRequest for more detail of the pointer typing,
    it's fun, I promise
   */
  public struct IntegerControl <T: BinaryInteger> : UVCIntegerControlInterface {

    
    public let name      : String
    public let selector  : UVC.Selector
    public let usb       : UVC.ControlRequestInterface
    public let uvctype   : UVC.ControlType
    public let uvcfamily : UVC.ControlFamily
    
    
    public init ( name: String, interface: USB.COMObject<IOUSBInterfaceInterface>, selector: UVC.Selector, type: UVC.ControlType, family: UVC.ControlFamily ) {
      self.name      = name
      self.selector  = selector
      self.usb       = UVC.ControlRequestInterface(usb: interface)
      self.uvctype   = type
      self.uvcfamily = family
      
    }
    
    
    
    public func current() -> Int? {
      if let value: T = usb.inRequest(request: .GET_CUR, selector: selector) {
        return Int(clamping: value)
      }
      return nil
    }
    
    
    public func set(value: Int) {
      _ = usb.outRequest ( request: .SET_CUR, selector: selector, value: T(clamping: value) )
    }

    
    /*
      these vaues are set by the hardware and will never change (until they do)
      so we only read them the once.
    */
    public lazy var max : Int? = {
      if let value : T = usb.inRequest(request: .GET_MAX, selector: selector) {
        return Int(clamping: value)
      }
      return nil
    }()
    
    
    public lazy var min : Int? = {
      if let value : T = usb.inRequest(request: .GET_MIN, selector: selector) {
        return Int(clamping: value)
      }
      return nil
    }()
    
    
    public lazy var `default` : Int? = {
      if let value : T = usb.inRequest(request: .GET_DEF, selector: selector) {
        return Int(clamping: value)
      }
      return nil
    }()
    
    
    public lazy var resolution : Int? = {
      if let value : T = usb.inRequest(request: .GET_RES, selector: selector) {
        return Int(clamping: value)
      }
      return nil
    }()
    
    
    
    // slightly different b/c this always returns a single byte may not matter really, but still, carefully does it
    public lazy var inf : UInt8? = {
      if let value : UInt8 = usb.inRequest (
        request  : .GET_INF,
        selector : UVC.Selector(index: UInt16(selector.index), target: selector.target)
      )
      {
        return value
      }
      return nil
    }()
    
  }
  
}


// for the looking

extension UVC.IntegerControl : CustomDebugStringConvertible {
  
  public var debugDescription : String {
    
    var mutableme = self
    
    let min  = (mutableme.min        != nil) ? String(mutableme.min!) : "_"
    let max  = (mutableme.max        != nil) ? String(mutableme.max!) : "_"
    let def  = (mutableme.default    != nil) ? String(mutableme.default!) : "_"
    let res  = (mutableme.resolution != nil) ? String(mutableme.resolution!) : "_"
    let inf  = (mutableme.inf        != nil) ? mutableme.inf! : 0
    
    let curv = mutableme.current()
    let cur  = (curv != nil) ? String(curv!) : "_"
    
    return
      "-> \(self.name) \nfam: \(self.uvcfamily), index: \(String(format: "%02x", self.selector.index)), type: \(self.uvctype) \n" +
      "resolution: \(res) min:  \(min), max: \(max), default: \(def), current: \(cur) \n" +
      "inf : \(String(repeating: "0", count: inf.leadingZeroBitCount))\(String(inf, radix: 2))\n"
  }
}


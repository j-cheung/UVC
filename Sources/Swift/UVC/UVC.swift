
import Foundation
import Descriptors



/*
  code for doing stuff with USB Video Class devices, e.g. web cams, etc.
  the specification for which can be found at
  https://www.usb.org/document-library/video-class-v15-document-set

  consts are defined in uvcconsts.swift
 
  UVC class descriptors are imported C structs (because packing) and live in
  descriptors.h
 
  the structs that are used are in an extension in uvctypes.swift
 */


public struct UVC {
    
  public init() {}
  
    let usb        = USB() // for doing USB thangz
    
    let processing = UVC.ProcessingUnit() // these two are defined lower down,
    let inputterm  = UVC.CameraTerminal() // just here to save some horrible naming clashes
  
    
  
    /*
      probe the USB interfaces of the device to find a UVC control interface
      (class == CC_VIDEO, subclass == SC_VIDEOCONTROL)
    */
  
    func probeInterfaces(device: io_object_t ) -> (interface: USB.COMObject<IOUSBInterfaceInterface>, device: USB.COMObject<IOUSBDeviceInterface>)? {
        
      
        // get a device interface
        guard let deviceInterface = usb.queryInterface( .device, for: device ) else { return nil }
        
        /*
          obtain an IOIterator that we can use to loop over the device's interfaces
          remember the IOIterator objects are just opaque handles (most of this stuff
          is just typealias to Int32), here we wrap it agaim  (see IOIterator.swift) for
          lifecyle management and slightly nicer semantics
        */
    
        var iterator  = IOIterator( io_iterator_t() )
        var request   = USB.findInterfaceRequest ( iclass: InterfaceClass.CC_VIDEO )
        
        /*
          note again I'm splatting the return, if this fails, the iterator will be IO_ITERATOR_NULL (0)
          and we'll return nil
        */
        _ = deviceInterface.instance.CreateInterfaceIterator ( deviceInterface.pointer, &request, &iterator.opaque )
      
      
        while let candidiate = iterator.next() {
          
          // get a COM object representing the actual interface
          
          if let interface = usb.queryInterface(.interface, for: candidiate) {
            
            var iclass : UInt8 = 0
            var isub   : UInt8 = 0
          
            // and check to see if has the UVC class and sublass for video conrtrols
            
            _ = interface.instance.GetInterfaceClass(interface.pointer, &iclass)
            _ = interface.instance.GetInterfaceSubClass(interface.pointer, &isub)
            
            if iclass == InterfaceClass.CC_VIDEO && isub == InterfaceClass.SC_VIDEOCONTROL { return (interface, deviceInterface)  }
          }
          
        }

        return nil
    }



    /*
      Yay. Pointers!
     
      Retrieve the VC_Processing_Unit_Descriptor and the VC_Input_Terminal_Descriptor
      mainly because we need their IDs, this is vexed, because swift, but follow along
      and for the love of god if there is a nicer way of doing this please let me know.
      There must be, right?
     
      
    */
    func getDescriptors ( uvc: USB.COMObject<IOUSBInterfaceInterface> ) -> (pud: VC_Processing_Unit_Descriptor?, itd: VC_Input_Terminal_Descriptor?) {
      
      var vcpud : VC_Processing_Unit_Descriptor? = nil
      var vcitd : VC_Input_Terminal_Descriptor?  = nil
      
      // find the class specific descriptor for USB Video
      guard let descriptor = uvc.instance.FindNextAssociatedDescriptor (
          uvc.pointer,
          nil,
          UInt8(InterfaceClass.CS_INTERFACE)
      )
      else { return (nil, nil) }
      
      
      // cast to C_VC_Header to read length
      
      let header = UnsafeMutableRawPointer(descriptor).bindMemory(to: C_VC_Header.self, capacity: 1)
      
      let length = Int(header.pointee.wTotalLength)
      var offset = Int(header.pointee.bLength)
      
      
      // cast to UInt8 so we can increment correctly as the rest of the chunks are not evenly sized
      
      let bytes = UnsafeMutableRawPointer(header).bindMemory(to: UInt8.self, capacity: length)
      
      while offset < length {
        
        let pref = bytes.advanced(by: offset)
        
        // withMemoryRebound allows us to access the bytes pointer as a different type without summoning nasal demons
        // we exploit the commanality at the begining of the descriptors to pull a sub type and length
        
        pref.withMemoryRebound(to: UVC_Descriptor_Prefix.self, capacity: 1) { prefix in
          offset += Int(prefix.pointee.bLength)
          
          if prefix.pointee.bDescriptorSubType == DescriptorSubType.VC_PROCESSING_UNIT {
            
            // rebind and retrieve the processing unit descriptor
            
            prefix.withMemoryRebound(to: VC_Processing_Unit_Descriptor.self, capacity: 1) { pud in
              vcpud = pud.pointee
            }
          }
          
          
          if prefix.pointee.bDescriptorSubType == DescriptorSubType.VC_INPUT_TERMINAL {
            
            // rebind and retrieve the camera terminal descriptor
            
            prefix.withMemoryRebound(to: VC_Input_Terminal_Descriptor.self, capacity: 1) { itd in
              vcitd = itd.pointee
            }
            
          }
        }
      }

      return (vcpud, vcitd)
    }


  
    /*
      enumerate all the devices on the USB bus which exhibit an Interface Association Descriptor
      (see below) and then probe them to see if they are UVC compliant devices, if so retrieve
      the relevant interface descriptors and add them to our collection.
    */
  
    public func enumerateDevices() -> [UVC.Camera] {
      
      var devices : [UVC.Camera] = []
      
      let uvcpattern : [String : Any] = [
        kIOProviderClassKey : kIOUSBDeviceClassName,
        kUSBVendorID        : "*",
        kUSBProductID       : "*",
        kUSBDeviceClass     : 0xef,
        kUSBDeviceSubClass  : 0x02,
        kUSBDeviceProtocol  : 0x01
      ]
      // NB these consts are spec'd as Interface Association Descriptor
      // in https://www.usb.org/sites/default/files/iadclasscode_r10.pdf
      // where they are unnamed. Since we only use them the once, I haven't named them
      
      
      for candidate in usb.enumerate(matching: uvcpattern) {
        if let interface = probeInterfaces(device: candidate) {
          
          let descriptors = getDescriptors(uvc: interface.interface)
          
          // design choice, we will only enumerate properly if we get both,
          // I think this is correct behaviour, but am not certain
          
          if let pud = descriptors.pud, let itd = descriptors.itd {
            devices.append( UVC.Camera(pud: pud, itd: itd, interface: interface.interface, device: interface.device, properties: usb.properties(of:candidate)) )
          }
        }
      }
      
      return devices
    }


    /*
      So, fun fact, one of the other reason for pulling the descriptors is that they contain
      a list of valid controls, except, they don't, necessarily. My cam acknowleged almost none
      of it's processing unit controls that way, so, we probe them by sending a GET_INF
      request. If this fails, that control is not there. Probably.
    */
  
    public func enumerateControls(uvc: UVC.Camera, target: UInt16, range: ClosedRange<Int> ) -> [Int] {
      
      var validcontrols : [Int] = []

      let endpoint = UVC.ControlRequestInterface(usb: uvc.interface)
      
      for i in range {
        
        // so, I tried sending GET_CUR, but didn't get as many controls, seems some don't wake up
        // or make themselves available until we poke them. Interesting.
        
        if let _ : UInt8 = endpoint.inRequest (
          request  : .GET_INF,
          selector : UVC.Selector(index: UInt16(i), target: target)
        )
        {
          validcontrols += [i]
        }
      }

      return validcontrols
    }
  
  
  /*
    Here is where we match up our control ids and map them into actual controls (or interafces there to).
    As of the now, there are just integer controls, as almost everything can be modelled as an int if you squint
    Also, I have here only included the ones I actually have available to test,
    the full list of types and controls is lurking at the bottom of uvcconsts.swift
  */
  
  struct ProcessingUnit { // syntactic sugar for API
  
    func constructIntegerControl(index: Int, unitID: UInt16, interface: USB.COMObject<IOUSBInterfaceInterface>) -> UVCIntegerControlInterface? {
      
      // convenience, save typing and make the below easier to read
      // everything except name and type is already determined, so why type it?
      
      func control<T: BinaryInteger>(name: String, type: T.Type, uvctype: UVC.ControlType, tag: UVC.Tag) -> UVCIntegerControlInterface {
        UVC.IntegerControl<T> (
          name     : name,
          interface: interface,
          selector : UVC.Selector(index: UInt16(index), target: unitID),
          type     : uvctype,
          family   : .camera,
          tag      : tag
        )
      }
      
      // cast to enum, so the enums are the single source of truth RE selector indexes
      guard let selindex = UVC.PUControlIndex(rawValue: index) else { return nil }
      
      switch selindex {
        
        case .backlight_comp           : return control ( name: "Backlight Compensation",   type: UInt16.self, uvctype: .int,       tag: .backlight_comp            )
        case .brightness               : return control ( name: "Brightness",               type: Int16.self , uvctype: .int,       tag: .brightness                )
        case .contrast                 : return control ( name: "Contrast",                 type: UInt16.self, uvctype: .int,       tag: .contrast                  )
        case .gain                     : return control ( name: "Gain",                     type: UInt16.self, uvctype: .int,       tag: .gain                      )
        case .power_line_freq          : return control ( name: "Powerline Frequency",      type: UInt8.self,  uvctype: .option,    tag: .power_line_freq           )
        case .hue                      : return control ( name: "Hue",                      type: Int16.self , uvctype: .int,       tag: .hue                       )
        case .saturation               : return control ( name: "Saturation",               type: UInt16.self, uvctype: .int,       tag: .saturation                )
        case .sharpness                : return control ( name: "Sharpness",                type: UInt16.self, uvctype: .int,       tag: .sharpness                 )
        case .gamma                    : return control ( name: "Gamma",                    type: UInt16.self, uvctype: .int,       tag: .gamma                     )
        case .white_bal_temp           : return control ( name: "White Balance Temp",       type: UInt16.self, uvctype: .int,       tag: .white_bal_temp            )
        case .white_bal_temp_auto      : return control ( name: "White Bal Temp Auto",      type: UInt8.self , uvctype: .bool,      tag: .white_bal_temp_auto       )
        case .white_bal_component      : return control ( name: "White Bal Component",      type: UInt32.self, uvctype: .multibyte, tag: .white_bal_component       )
        case .white_bal_component_auto : return control ( name: "White Bal Component Auto", type: UInt8.self,  uvctype: .bool,      tag : .white_bal_component_auto )
        case .digi_mult                : return control ( name: "Digital Multiplier",       type: UInt16.self, uvctype: .int,       tag: .digi_mult                 )
        case .digi_mult_limit          : return control ( name: "Digital Multiplier Limit", type: UInt16.self, uvctype: .int,       tag: .digi_mult_limit           )
        case .hue_auto                 : return control ( name: "Hue Auto",                 type: UInt8.self,  uvctype: .bool,      tag: .hue_auto                  )
        case .analogue_vid_std         : return control ( name: "Analogue Video Standard",  type: UInt8.self,  uvctype: .int,       tag: .analogue_vid_std          )
        case .analogue_lock            : return control ( name: "Analogue Lock",            type: UInt8.self,  uvctype: .int,       tag: .analogue_lock             )
        case .contrast_auto            : return control ( name: "Contrast Auto",            type: UInt8.self,  uvctype: .int,       tag: .contrast_auto             )
      }
    }
  }

  
  
  struct CameraTerminal { // syntactic sugar for API

    func constructIntegerControl(index: Int, unitID: UInt16, interface: USB.COMObject<IOUSBInterfaceInterface>) -> UVCIntegerControlInterface? {
      
      // convenience, save typing and make the below easier to read
      // everything except name and type is already determined, so why type it?
      
      func control<T: BinaryInteger>(name: String, type: T.Type, uvctype: UVC.ControlType, tag: UVC.Tag) -> UVCIntegerControlInterface {
        UVC.IntegerControl<T> (
          name     : name,
          interface: interface,
          selector : UVC.Selector(index: UInt16(index), target: unitID),
          type     : uvctype,
          family   : .camera,
          tag      : tag
        )
      }
      
      // cast to enum, so the enums are the single source of truth RE selector indexes
      guard let selindex = UVC.CTControlIndex(rawValue: index) else { return nil }
      
      switch selindex {
        case .scan_mode    : return control ( name: "Scanning Mode",        type: UInt8.self,  uvctype: .option,    tag: .scan_mode    )
        case .ae_mode      : return control ( name: "AE Mode",              type: UInt8.self,  uvctype: .bitmap,    tag: .ae_mode      )
        case .ae_priority  : return control ( name: "AE Priorty",           type: UInt8.self,  uvctype: .bool,      tag: .ae_priority  )
        case .exp_time_abs : return control ( name: "Exposure Time (abs)",  type: UInt32.self, uvctype: .int,       tag: .exp_time_abs )
        case .exp_time_rel : return control ( name: "Exposure Time (rel)",  type: UInt8.self,  uvctype: .int,       tag: .exp_time_rel )
        case .focus_abs    : return control ( name: "Focus (abs)",          type: UInt16.self, uvctype: .int,       tag: .focus_abs    )
        case .focus_rel    : return control ( name: "Focus (rel)",          type: UInt16.self, uvctype: .multibyte, tag: .focus_rel    )
        case .focus_auto   : return control ( name: "Focus Auto",           type: UInt8.self,  uvctype: .bool,      tag: .focus_auto   )
        case .iris_abs     : return control ( name: "Iris (abs)",           type: UInt16.self, uvctype: .int,       tag: .iris_abs     )
        case .iris_rel     : return control ( name: "Iris (rel)",           type: UInt8.self,  uvctype: .int,       tag: .iris_rel     )
        case .zoom_abs     : return control ( name: "Zoom (abs)",           type: UInt16.self, uvctype: .int,       tag: .zoom_abs     )
        case .zoom_rel     : return control ( name: "Zoom (rel)",           type: UInt16.self, uvctype: .multibyte, tag: .zoom_rel     )
        case .pantilt_abs  : return control ( name: "Pan/Tilt (abs)",       type: UInt64.self, uvctype: .multibyte, tag: .pantilt_abs  )
        case .pantilt_rel  : return control ( name: "Pan/Tilt (rel)",       type: UInt32.self, uvctype: .multibyte, tag: .pantilt_rel  )
        case .roll_abs     : return control ( name: "Roll (abs)",           type: UInt16.self, uvctype: .int,       tag: .roll_abs     )
        case .roll_rel     : return control ( name: "Roll (rel)",           type: UInt16.self, uvctype: .multibyte, tag: .roll_rel     )
        case .privacy      : return control ( name: "Privacy",              type: UInt8.self,  uvctype: .bool,      tag: .privacy      )
        case .focus_simple : return control ( name: "Focus Simple",         type: UInt8.self,  uvctype: .int,       tag: .focus_simple )
        
        /*
          aaand, that's where we stop, b/c a) swift doesnt actually expose a [U]Int128
                                           b) it wouldn't really fit this model anyway, come back in a bit
          case .window
          case .roi
        */
        
        // case .window, .roi : fatalError("Apologies, Digital Window and ROI not impelmented yet, come back in a bit, I will get to them. I gotchu fam x")
        case .window, .roi: return nil

      }
    }
  }
  
  /*
    Hi! FInally the one you've been looking for.
    gather all the valid controls for this camera and stuff them in a big collection hidden
    behind an interface(s)
    
  */
  public func getCameraControls (camera: UVC.Camera) -> [UVCIntegerControlInterface] {
    
    var controls: [UVCIntegerControlInterface] = []

    let pucontrols = enumerateControls(uvc: camera, target: camera.punitID, range: 0x01...0x13 )


    for index in pucontrols {
      if let obj = processing.constructIntegerControl(index: index, unitID: camera.punitID, interface: camera.interface) {
        controls += [obj]
      }
    }


    let itcontrols = enumerateControls(uvc: camera, target: camera.itermID, range: 0x01...0x14 )

    for index in itcontrols {
      if let obj = inputterm.constructIntegerControl(index: index, unitID: camera.itermID, interface: camera.interface) {
        controls += [obj]
      }
    }
    
    return controls
  }
}



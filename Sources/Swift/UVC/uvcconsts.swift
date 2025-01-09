
import Foundation

/*
 Various constants for doing UVC things, these are all defined in
 Universal Serial Bus Device Class Definition for Video Devices
 https://www.usb.org/document-library/video-class-v15-document-set
 
*/
extension UVC {

  
    
    /*
      for identifying the control interface and finding the right descriptors
      see section 3, Descriptors
    */
  
    struct InterfaceClass {
      static let CC_VIDEO        : UInt16 = 0xe
      static let SC_VIDEOCONTROL : UInt16 = 0x01
      static let CS_INTERFACE    : UInt16 = 0x24
    }
  
  
    struct DescriptorSubType {
      static let VC_PROCESSING_UNIT : UInt16 = 0x05
      static let VC_INPUT_TERMINAL  : UInt16 = 0x02
    }
  
  
  
    /*
     UVC request codes, see section 4.2 of USB Device Class Definition for Video Devices
    */
    public enum RequestCode : UInt8 {
      
      case SET_CUR = 0x01
      
      case GET_CUR = 0x81
      case GET_MIN = 0x82
      case GET_MAX = 0x83
      case GET_RES = 0x84
      case GET_LEN = 0x85
      case GET_INF = 0x86
      case GET_DEF = 0x87
      
    }

    /*
      Processing unit control selectors.
      When we want to talk to a control, we address it by these numbers,
      these are defined in Appendix A
    */
  
  
    public enum PUControlIndex : Int {
                                                
      case backlight_comp           = 0x01
      case brightness               = 0x02
      case contrast                 = 0x03
      case gain                     = 0x04
      case power_line_freq          = 0x05
      case hue                      = 0x06
      case saturation               = 0x07
      case sharpness                = 0x08
      case gamma                    = 0x09
      case white_bal_temp           = 0x0A
      case white_bal_temp_auto      = 0x0B
      case white_bal_component      = 0x0C
      case white_bal_component_auto = 0x0D
      case digi_mult                = 0x0E
      case digi_mult_limit          = 0x0F
      case hue_auto                 = 0x10
      case analogue_vid_std         = 0x11
      case analogue_lock            = 0x12
      case contrast_auto            = 0x13
    }


    /*
     Camera terminal/Input terminal control selectors,
     ibid
    */
  
    public enum CTControlIndex : Int {

      case scan_mode    = 0x01
      case ae_mode      = 0x02
      case ae_priority  = 0x03
      case exp_time_abs = 0x04
      case exp_time_rel = 0x05
      case focus_abs    = 0x06
      case focus_rel    = 0x07
      case focus_auto   = 0x08
      case iris_abs     = 0x09
      case iris_rel     = 0x0A
      case zoom_abs     = 0x0B
      case zoom_rel     = 0x0C
      case pantilt_abs  = 0x0D
      case pantilt_rel  = 0x0E
      case roll_abs     = 0x0F
      case roll_rel     = 0x10
      case privacy      = 0x11
      case focus_simple = 0x12
      case window       = 0x13
      case roi          = 0x14
    }

  
    /*
      added because I wanted to have a global tag, makes control construction somewhat
      noisy, but e.g, will be easier to find them later.
    */
  
    public enum Tag {
      
      // processing unit
      
      case backlight_comp
      case brightness
      case contrast
      case gain
      case power_line_freq
      case hue
      case saturation
      case sharpness
      case gamma
      case white_bal_temp
      case white_bal_temp_auto
      case white_bal_component
      case white_bal_component_auto
      case digi_mult
      case digi_mult_limit
      case hue_auto
      case analogue_vid_std
      case analogue_lock
      case contrast_auto            
      
      // input terminal
      
      case scan_mode
      case ae_mode
      case ae_priority
      case exp_time_abs
      case exp_time_rel
      case focus_abs
      case focus_rel
      case focus_auto
      case iris_abs
      case iris_rel
      case zoom_abs
      case zoom_rel
      case pantilt_abs
      case pantilt_rel
      case roll_abs
      case roll_rel
      case privacy
      case focus_simple
      case window
      case roi
    }
  
    /*
      these ones tag the control so we can identify them by family
      and type later as well as their selector
    */
  
    public enum ControlType {
      case bool, bitmap, int, multibyte, option
    }

    public enum ControlFamily {
      case processing, camera
    }
    
  
  
  
  
  // while I am not using these anynore, they remain as a central listing of the control types
  // in one place so I dont have to go look it up again, we will add the rest later, maybe
  
  //    func constructPUControl(index: UInt16, pu: UInt16) -> ControlInfo? {
  //
  //      func ofSize(_ size : UInt16, type: ControlType) -> UVC.ControlSelector {
  //        UVC.ControlSelector(index: index, size: size, target: pu, type: type)
  //      }
  //
  //      switch index {
  //
  //        case 0x01 : return ControlInfo(name: "Backlight Compensation",         selector: ofSize(2, type: .int     ) )
  //        case 0x02 : return ControlInfo(name: "Brightness",                     selector: ofSize(2, type: .signed  ) )
  //        case 0x03 : return ControlInfo(name: "Contrast",                       selector: ofSize(2, type: .int     ) )
  //        case 0x04 : return ControlInfo(name: "Gain",                           selector: ofSize(2, type: .int     ) )
  
  //        case 0x05 : return ControlInfo(name: "Power Line Frequency",           selector: ofSize(1, type: .option  ) )
  
  //        case 0x06 : return ControlInfo(name: "Hue",                            selector: ofSize(2, type: .signed  ) )
  //        case 0x07 : return ControlInfo(name: "Saturation",                     selector: ofSize(2, type: .int     ) )
  //        case 0x08 : return ControlInfo(name: "Sharpness",                      selector: ofSize(2, type: .int     ) )
  //        case 0x09 : return ControlInfo(name: "Gamma",                          selector: ofSize(2, type: .int     ) )
  //        case 0x0A : return ControlInfo(name: "White Balance Temperature",      selector: ofSize(2, type: .int     ) )
  //        case 0x0B : return ControlInfo(name: "White Balance Temperature Auto", selector: ofSize(1, type: .bool    ) )
  //        case 0x0C : return ControlInfo(name: "White Balance Component",        selector: ofSize(4, type: .multibyte) )
  //        case 0x0D : return ControlInfo(name: "White Balance Component Auto",   selector: ofSize(1, type: .bool    ) )
  //        case 0x0E : return ControlInfo(name: "Digital Multiplier",             selector: ofSize(2, type: .int     ) )
  //        case 0x0F : return ControlInfo(name: "Digital Multiplier Limit",       selector: ofSize(2, type: .int     ) )
  //        case 0x10 : return ControlInfo(name: "Hue Auto",                       selector: ofSize(1, type: .bool    ) )
  //        case 0x11 : return ControlInfo(name: "Analogue Video Standard",        selector: ofSize(1, type: .int     ) )
  //        case 0x12 : return ControlInfo(name: "Analogue Lock Status",           selector: ofSize(1, type: .int     ) )
  //        case 0x13 : return ControlInfo(name: "Contrast Auto",                  selector: ofSize(1, type: .bool    ) )
  //
  //        default : return nil
  //      }
  //
  //    }
  //
  //
//
//
//    func constructCTControl(index: UInt16, it: UInt16) -> ControlInfo? {
//
//      func ofSize(_ size : UInt16, type: ControlType) -> UVC.ControlSelector {
//        UVC.ControlSelector(index: index, size: size, target: it, type: type)
//      }
//
//      switch index {
//        case 0x01 : return ControlInfo(name: "Scanning Mode",          selector: ofSize(1, type: .option   ))
//        case 0x02 : return ControlInfo(name: "Auto Exposure Mode",     selector: ofSize(1, type: .bitmap   ))
//        case 0x03 : return ControlInfo(name: "Auto Exposure Priority", selector: ofSize(1, type: .bool     ))
//        case 0x04 : return ControlInfo(name: "Exposure Time (abs)",    selector: ofSize(4, type: .int      ))
//        case 0x05 : return ControlInfo(name: "Exposure Time (rel)",    selector: ofSize(1, type: .int      ))
//        case 0x06 : return ControlInfo(name: "Focus (abs)",            selector: ofSize(2, type: .int      ))
//        case 0x07 : return ControlInfo(name: "Focus (rel)",            selector: ofSize(2, type: .multibyte))
//        case 0x08 : return ControlInfo(name: "Focus Auto",             selector: ofSize(1, type: .bool     ))
//        case 0x09 : return ControlInfo(name: "Iris (abs)",             selector: ofSize(2, type: .int      ))
//        case 0x0A : return ControlInfo(name: "Iris (rel)",             selector: ofSize(1, type: .int      ))
//        case 0x0B : return ControlInfo(name: "Zoom (abs)",             selector: ofSize(2, type: .int      ))
//        case 0x0C : return ControlInfo(name: "Zoom (rel)",             selector: ofSize(2, type: .multibyte))
//        case 0x0D : return ControlInfo(name: "Pan/Tilt (abs)",         selector: ofSize(8, type: .multibyte))
//        case 0x0E : return ControlInfo(name: "Pan/Tilt (rel)",         selector: ofSize(4, type: .multibyte))
//        case 0x0F : return ControlInfo(name: "Roll (abs)",             selector: ofSize(2, type: .int      ))
//        case 0x10 : return ControlInfo(name: "Roll (rel)",             selector: ofSize(2, type: .multibyte))
//        case 0x11 : return ControlInfo(name: "Privacy",                selector: ofSize(1, type: .bool     ))
//        case 0x12 : return ControlInfo(name: "Focus Simple",           selector: ofSize(1, type: .int      ))
//
//        // srsly?
//        case 0x13 : return ControlInfo(name: "Digital WIndow",         selector: ofSize(12, type: .multibyte)) // ***
//        case 0x14 : return ControlInfo(name: "Region OF Interest",     selector: ofSize(10, type: .multibyte)) // bigger than Int
//
//        default : return nil
//      }
//    }
}


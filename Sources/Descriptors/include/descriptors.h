
#ifndef descriptors_h
#define descriptors_h

#include <stdint.h>

/*

 structs for USB Video Class descriptors
 NB : 1) they are incomplete, I am only pulling as much as I need
      
      2) they are defined as C structs because then we can use
         __attribute__((packed)) which does not work in swift, which
         we need because these are provided as pointers by the C API and
         swift structs just can't be used that way, as of the now.
      
      3) I say 'need' but TBH we probably dont actually need anything other than
         the unit and terminal IDs as the control collections dont appear to
         be accurate on my camera, and I used a different way of enumerating
         the actual controls, go figure.
*/

typedef struct {
  uint8_t    bLength;
  uint8_t    bDescriptorType;
  uint8_t    bDescriptorSubType;
  uint16_t   bcdUVC;
  uint16_t   wTotalLength;
  uint32_t   dwClockFrequency;
  uint8_t    bInCollection;
  uint8_t    bInterfaceNr1;
}  __attribute__((packed)) C_VC_Header;


typedef struct {
  uint8_t    bLength;
  uint8_t    bDescriptorType;
  uint8_t    bDescriptorSubType;
}
__attribute__((packed)) UVC_Descriptor_Prefix;


typedef struct {
  uint8_t     bLength;
  uint8_t     bDescriptorType;
  uint8_t     bDescriptorSubType;
  uint8_t     bUnitID;
  uint8_t     bSourceID;
  uint8_t     wMaxMultiplier;
  uint8_t     bControlSize;
  uint8_t     bmControls[3];
  // ...
} __attribute__((packed)) VC_Processing_Unit_Descriptor;


typedef struct {
  uint8_t    bLength;
  uint8_t    bDescriptorType;
  uint8_t    bDescriptorSubType;
  uint8_t    bTerminalID;
  uint16_t   wTerminalType;
  uint8_t    bAssocTerminal;
  uint8_t    iTerminal;
  uint16_t   wObjectiveFocalLengthMin;
  uint16_t   wObjectiveFocalLengthMax;
  uint16_t   wOcularFocalLength;
  uint8_t    bControlSize;
  uint8_t    bmControls[3];

} __attribute__((packed)) VC_Input_Terminal_Descriptor;




typedef struct {
  uint8_t  bStatusType;
  uint8_t  bOriginator;
  uint8_t  bEvent;
  uint8_t  bSelector;
  uint8_t  bAttribute;
  uint8_t  unk;
} __attribute__((packed)) InterruptRequest;



#endif /* descriptors_h */


import Foundation
import IOKit


/*
  wrap IOIterator for slightly nicer loop pattern and also to automagically
  manage the lifecycle. we're responsible for these and if we don't release
  them they'll just live forever in the kernel with nothing to do.
 
  existence is pain for a meseeks, jerry.
*/

public struct IOIterator {
  
  /*
    we'll sometimes need to pass a pointer to this, so var it is
  */
  public var opaque : io_iterator_t

  public init(_ iterator: io_iterator_t) { self.opaque = iterator }

  public func next() -> io_object_t? {
    
    let object = IOIteratorNext(opaque)
    
    defer {
      if object == IO_OBJECT_NULL {
        IOObjectRelease(opaque)
      }
    }
    return object == IO_OBJECT_NULL ? nil : object
  }

}

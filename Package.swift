// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name    : "UVC",
    products: [ .library( name: "UVC", targets: ["UVC"]), ],
    dependencies: [ ],
    targets: [
      
        .target(
          name: "UVC",
          dependencies: ["Descriptors"],
          path: "Sources/Swift"
        ),
        
        .target(
          name: "Descriptors",
          path: "Sources/Descriptors"
        ),

    ]
)

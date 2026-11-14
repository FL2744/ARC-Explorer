// swift-tools-version: 6.0
import PackageDescription
let package=Package(name:"ARCExplorer",platforms:[.macOS(.v15)],dependencies:[.package(path:"Vendor/SwiftTerm")],targets:[
 .executableTarget(name:"ARC-Explorer",dependencies:[.product(name:"SwiftTerm",package:"SwiftTerm")],path:"Sources",exclude:["Askpass.swift","Icon.swift"]),
 .testTarget(name:"TerminalIntegrationTests",dependencies:["ARC-Explorer",.product(name:"SwiftTerm",package:"SwiftTerm")],path:"NativeTests")
],swiftLanguageModes:[.v5])

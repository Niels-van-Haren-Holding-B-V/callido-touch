// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CallidoTouch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CallidoTouch", targets: ["CallidoTouch"]),
    ],
    targets: [
        // Pure logic: HID descriptor parsing, report decoding, gesture recognition.
        // No AppKit / IOKit, so it can be unit tested in isolation.
        .target(name: "CallidoTouchCore"),
        .executableTarget(
            name: "CallidoTouch",
            dependencies: ["CallidoTouchCore"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(name: "CallidoTouchCoreTests", dependencies: ["CallidoTouchCore"]),
    ]
)

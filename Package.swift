// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AutoCaptureOCR",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AutoCaptureOCR",
            path: "Sources/AutoCaptureOCR",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Vision"),
                .linkedFramework("Accelerate"),
            ]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
	name: "GrayGpuImage",
	platforms: [.macOS(.v10_15), .iOS(.v16)],
	products: [
		.library(
			name: "GrayGpuImage",
			targets: ["GrayGpuImage"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
	],
	targets: [
		.macro(
			name: "GrayGpuImageMacrosImpl",
			dependencies: [
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax")
			]
		),
		.target(
			name: "GrayGpuImage",
			dependencies: ["GrayGpuImageMacrosImpl"]
		),
		.testTarget(name: "GrayGpuImageTest",
			dependencies: ["GrayGpuImage"]
		)
	]
)

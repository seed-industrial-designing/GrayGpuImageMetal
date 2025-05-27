import Metal
import Foundation
import CoreGraphics

public protocol GrayGpuImageFunction
{
	static var functionDescriptors: [GrayGpuContext.FunctionDescriptor] { get }
	func setupComputeEncoder(_ encoder: MTLComputeCommandEncoder, context: GrayGpuContext) throws
}
public protocol GrayGpuImageGenerator: GrayGpuImageFunction {}
public protocol GrayGpuImageFilter: GrayGpuImageFunction {}

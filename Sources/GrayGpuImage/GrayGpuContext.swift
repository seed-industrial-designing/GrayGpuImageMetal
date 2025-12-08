//
// GrayGpuImage
// Copyright © 2025 Seed Industrial Designing Co., Ltd. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software
// and associated documentation files (the “Software”), to deal in the Software without
// restriction, including without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom
// the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Metal
import MetalKit

public class GrayGpuContext
{
	let device: MTLDevice
	let commandQueue: MTLCommandQueue
	private var pipelineStates: [(descriptor: FunctionDescriptor, pipelineState: MTLComputePipelineState)] = []
	var librariesForBundle: [Bundle: MTLLibrary] = [:]
	
	public init() throws(InitializationError)
	{
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw InitializationError.noDevice
		}
		guard let commandQueue = device.makeCommandQueue() else {
			throw InitializationError.noCommandQueue
		}
		self.device = device
		self.commandQueue = commandQueue
	}
	
	let pipelineStateLock = NSLock()
	public func pipelineState(for functionDescriptor: FunctionDescriptor) throws -> MTLComputePipelineState?
	{
		pipelineStateLock.lock()
		defer { pipelineStateLock.unlock() }
		
		if let result = pipelineStates.first(where: { $0.descriptor == functionDescriptor })?.pipelineState {
			return result
		} else {
			let library = try {
				if let library = librariesForBundle[functionDescriptor.bundle] {
					return library
				} else {
					let library = try device.makeDefaultLibrary(bundle: functionDescriptor.bundle)
					librariesForBundle[functionDescriptor.bundle] = library
					return library
				}
			}()
			guard let function = library.makeFunction(name: functionDescriptor.name) else {
				throw FuncionError.noFunction(name: functionDescriptor.name)
			}
			let pipelineState = try device.makeComputePipelineState(function: function)
			pipelineStates.append((
				descriptor: functionDescriptor,
				pipelineState: pipelineState
			))
			return pipelineState
		}
	}
}

//MARK: - Errors

extension GrayGpuContext
{
	public enum InitializationError: Error
	{
		case noDevice
		case noCommandQueue
	}
	public enum FuncionError: Error
	{
		case noFunction(name: String)
	}
}

//MARK: - Function Descriptor

extension GrayGpuContext
{
	public struct FunctionDescriptor: Hashable, Equatable
	{
		public init(bundle: Bundle, name: String)
		{
			self.bundle = bundle
			self.name = name
		}
		var bundle: Bundle
		var name: String
	}
}

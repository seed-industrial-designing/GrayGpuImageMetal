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

public class GrayGpuImage
{
	let context: GrayGpuContext
	var textureA: MTLTexture
	var textureB: MTLTexture?
	
	//MARK: - Initializer
	
	public init?(context: GrayGpuContext, size: (width: Int, height: Int))
	{
		self.context = context
		guard let texture = context.device.makeTexture(descriptor: Self.textureDescriptor(size: size)) else {
			return nil
		}
		textureA = texture
	}
	
	//MARK: - Replacing
	
	public func replace(withGray8Pixels pixels: [UInt8], size: (width: Int, height: Int)? = nil, bytesPerRow: Int)
	{
		if let size, (textureA.width != size.width) || (textureA.height != size.height) {
			textureA = context.device.makeTexture(
				descriptor: Self.textureDescriptor(size: size)
			)!
			textureB = nil
		}
		let size = size ?? (width: textureA.width, height: textureA.height)
		textureA.replace(
			region: MTLRegionMake2D(0, 0, size.width, size.height),
			mipmapLevel: 0,
			withBytes: pixels,
			bytesPerRow: bytesPerRow
		)
	}
	public func replace(with other: GrayGpuImage)
	{
		_replace(copying: other.textureA)
	}
	private func _replace(copying texture: MTLTexture)
	{
		if (textureA.width != texture.width) || (textureA.height != texture.height) {
			textureA = context.device.makeTexture(descriptor: textureDescriptor(for: texture))!
		}
		
		guard
			let commandBuffer = context.commandQueue.makeCommandBuffer(),
			let blitEncoder = commandBuffer.makeBlitCommandEncoder()
		else {
			return
		}
		blitEncoder.copy(
			from: texture,
			sourceSlice: 0,
			sourceLevel: 0,
			sourceOrigin: .init(x: 0, y: 0, z: 0),
			sourceSize: .init(width: texture.width, height: texture.height, depth: 1),
			to: textureA,
			destinationSlice: 0,
			destinationLevel: 0,
			destinationOrigin: .init(x: 0, y: 0, z: 0)
		)
		blitEncoder.endEncoding()
		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()
	}
	
	//MARK: - Output
	
	public func getBytes(_ buffer: UnsafeMutableRawPointer, bytesPerRow: Int, from region: MTLRegion? = nil)
	{
		let size = (width: textureA.width, height: textureA.height)
		textureA.getBytes(
			buffer,
			bytesPerRow: bytesPerRow,
			from: region ?? MTLRegionMake2D(0, 0, size.width, size.height),
			mipmapLevel: 0
		)
	}
	
	//MARK: - Filter
	
	enum FunctionError: Error
	{
		case noCommandBuffer
		case noComputeEncoder
		case noTexture
	}
	public func apply(_ generator: GrayGpuImageGenerator) throws
	{
		guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
			throw FunctionError.noCommandBuffer
		}
		guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
			throw FunctionError.noComputeEncoder
		}
		try generator.setupComputeEncoder(computeEncoder, context: context)
		computeEncoder.setTexture(textureA, index: 0)
		
		let size = (width: textureA.width, height: textureA.height)
		let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
		let threadGroups = MTLSize(
			width: ((size.width + threadGroupSize.width - 1) / threadGroupSize.width),
			height: ((size.height + threadGroupSize.height - 1) / threadGroupSize.height),
			depth: 1
		)
		computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
		
		computeEncoder.endEncoding()
		commandBuffer.commit()
		commandBuffer.waitUntilCompleted()
	}
	public func apply(filter: GrayGpuImageFilter, outputSize: (width: Int, height: Int)) throws
	{
		guard (outputSize != (textureA.width, textureA.height)) else {
			return try apply(filters: [filter])
		}
		guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
			throw FunctionError.noCommandBuffer
		}
		guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
			throw FunctionError.noComputeEncoder
		}
		textureB = nil
		guard let outputTexture = context.device.makeTexture(descriptor: Self.textureDescriptor(size: outputSize)) else {
			throw FunctionError.noTexture
		}
		do {
			defer {
				computeEncoder.endEncoding()
				commandBuffer.commit()
				commandBuffer.waitUntilCompleted()
			}
			try filter.setupComputeEncoder(computeEncoder, context: context)
			computeEncoder.setTexture(textureA, index: 0)
			computeEncoder.setTexture(textureB, index: 1)
			
			let size = (width: textureA.width, height: textureA.height)
			let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
			let threadGroups = MTLSize(
				width: ((size.width + threadGroupSize.width - 1) / threadGroupSize.width),
				height: ((size.height + threadGroupSize.height - 1) / threadGroupSize.height),
				depth: 1
			)
			computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
		}
		self.textureA = outputTexture
		self.textureB = nil
	}
	public func apply(filters: [GrayGpuImageFilter]) throws
	{
		guard let commandBuffer = context.commandQueue.makeCommandBuffer() else {
			throw FunctionError.noCommandBuffer
		}
		guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
			throw FunctionError.noComputeEncoder
		}
		guard let textureB = textureB ?? context.device.makeTexture(descriptor: textureDescriptor(for: nil)) else {
			throw FunctionError.noTexture
		}
		var textureCoin = Coin(a: textureA, b: textureB)
		do {
			defer {
				computeEncoder.endEncoding()
				commandBuffer.commit()
				commandBuffer.waitUntilCompleted()
			}
			for filter in filters {
				try filter.setupComputeEncoder(computeEncoder, context: context)
				computeEncoder.setTexture(textureCoin.a, index: 0)
				computeEncoder.setTexture(textureCoin.b, index: 1)
				
				let size = (width: textureA.width, height: textureA.height)
				let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
				let threadGroups = MTLSize(
					width: ((size.width + threadGroupSize.width - 1) / threadGroupSize.width),
					height: ((size.height + threadGroupSize.height - 1) / threadGroupSize.height),
					depth: 1
				)
				computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
				
				textureCoin.flip()
			}
		}		
		self.textureA = textureCoin.a
		self.textureB = textureCoin.b
	}
	
	struct Coin<T>
	{
		var a: T
		var b: T
		mutating func flip() { self = .init(a: b, b: a) }
	}
	
	//MARK: - Texture Descriptor
	
	func textureDescriptor(for texture: MTLTexture? = nil) -> MTLTextureDescriptor
	{
		let texture = texture ?? textureA
		return Self.textureDescriptor(size: (width: texture.width, height: texture.height))
	}
	static func textureDescriptor(size: (width: Int, height: Int)) -> MTLTextureDescriptor
	{
		let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
			pixelFormat: .r8Unorm,
			width: size.width,
			height: size.height,
			mipmapped: false
		)
		textureDescriptor.usage = [.shaderRead, .shaderWrite]
		return textureDescriptor
	}
}

//MARK: - Core Graphics

#if canImport(CoreGraphics)

import CoreGraphics

public extension GrayGpuImage
{
	func makeCgImage(from region: MTLRegion? = nil) -> CGImage
	{
		let size = (width: textureA.width, height: textureA.height)
		var resultBytes = [UInt8](repeating: 0, count: (size.width * size.height)); do {
			getBytes(&resultBytes, bytesPerRow: size.width, from: region)
		}
		let resultContext = CGContext(
			data: &resultBytes,
			width: size.width,
			height: size.height,
			bitsPerComponent: 8,
			bytesPerRow: size.width,
			space: CGColorSpaceCreateDeviceGray(),
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		)!
		return resultContext.makeImage()!
	}
}

#endif

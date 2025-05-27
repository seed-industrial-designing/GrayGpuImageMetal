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

import Foundation

public protocol GrayGpuImageFunctionParameter
{
	associatedtype MetalValue
	var metalValue: MetalValue { get }
}
public extension GrayGpuImageFunctionParameter
{
	var metalValueLength: Int { MemoryLayout<MetalValue>.size }
}
public protocol GrayGpuImageFunctionParameterWithoutConversion: GrayGpuImageFunctionParameter { }
public extension GrayGpuImageFunctionParameterWithoutConversion
{
	var metalValue: Self { self }
}

//MARK: - Simple Types

extension Double: GrayGpuImageFunctionParameter
{
	public var metalValue: Float { .init(self) }
}
extension Int: GrayGpuImageFunctionParameter
{
	public var metalValue: Int32 { .init(self) }
}
extension CGPoint: GrayGpuImageFunctionParameter
{
	public var metalValue: SIMD2<Float> { .init(.init(x), .init(y)) }
}
extension CGSize: GrayGpuImageFunctionParameter
{
	public var metalValue: SIMD2<Float> { .init(.init(width), .init(height)) }
}

//MARK: - Range

extension ClosedRange: GrayGpuImageFunctionParameter where Bound: GrayGpuImageFunctionParameter, Bound.MetalValue: SIMDScalar
{
	public var metalValue: SIMD2<Bound.MetalValue> { .init(lowerBound.metalValue, upperBound.metalValue) }
}

//MARK: - Collection

extension Collection where Element: GrayGpuImageFunctionParameter
{
	public var metalValue: [Element.MetalValue] { map(\.metalValue) }
	var metalValueLength: Int { MemoryLayout<Element.MetalValue>.size * count }
}
extension Collection where Element: RawRepresentable, Element.RawValue: GrayGpuImageFunctionParameter
{
	public var metalValue: [Element.RawValue.MetalValue] { map(\.metalValue) }
	var metalValueLength: Int { MemoryLayout<Element.RawValue.MetalValue>.size * count }
}

//MARK: - RawRepresentable

extension RawRepresentable where RawValue: GrayGpuImageFunctionParameter
{
	public var metalValue: RawValue.MetalValue { rawValue.metalValue }
	var metalValueLength: Int { rawValue.metalValueLength }
}
extension Int32: GrayGpuImageFunctionParameterWithoutConversion { }
extension Float: GrayGpuImageFunctionParameterWithoutConversion { }
extension UInt32: GrayGpuImageFunctionParameterWithoutConversion { }
extension Bool: GrayGpuImageFunctionParameterWithoutConversion { }

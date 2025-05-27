//
// GrayGpuImageTest
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
import Testing
import GrayGpuImage
import Metal

@GrayGpuImageFilter enum MyFilter
{
	case doSomething(value: Double)
}
@Test func useFilters() throws
{
	let context = try GrayGpuContext()
	
	let image = GrayGpuImage(context: context, size: (1, 1))!
	image.replace(withGray8Pixels: [0xFF], bytesPerRow: 1)
	try image.apply(filters: [
		MyFilter.doSomething(value: 0.8),
		GrayGpuImageBuiltinFilter.level(blackLevel: 0.1, gamma: 0.5, whiteLevel: 0.9)
	])
	
	var buffer = [UInt8](repeating: 0x0, count: 1)
	image.getBytes(&buffer, bytesPerRow: 1)
	
	#expect(buffer[0] == 195)
}

@Test(arguments: [(128, 0.5), (192, 0.75), (255, 1.0)])
func useGenerator(color: (byte: UInt8, double: Double)) throws
{
	let context = try GrayGpuContext()
	
	let image = GrayGpuImage(context: context, size: (1, 1))!
	try image.apply(GrayGpuImageBuiltinGenerator.solidColor(color: color.double))
	
	var buffer = [UInt8](repeating: 0x0, count: 1)
	image.getBytes(&buffer, bytesPerRow: 1)

	#expect(abs(Int(buffer[0]) - Int(color.byte)) < 2)
}

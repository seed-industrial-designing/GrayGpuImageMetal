//
// GrayGpuImageDemo
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

import Cocoa
import SwiftUI
import Metal
import GrayGpuImage

class ViewController: NSViewController
{
	@IBOutlet var imageView: NSImageView!
	@IBOutlet var thresholdCheckbox: NSButton!

	@IBOutlet var thresholdSlider: NSSlider!
	@IBOutlet var gammaSlider: NSSlider!
	@IBOutlet var blurSlider: NSSlider!
	@IBOutlet var orientationSlider: NSSlider!

	var gpuContext = try! GrayGpuContext()
	var originalGpuImage: GrayGpuImage!
	var workingGpuImage: GrayGpuImage!
	let size = (width: 800, height: 800)
	
	//MARK: - Original Image
	
	static func sampleImageBytes(size: (width: Int, height: Int)) -> [UInt8]
	{
		var bytes = [UInt8](repeating: 0, count: size.width * size.height)
		let cgContext = CGContext(
			data: &bytes,
			width: size.width,
			height: size.height,
			bitsPerComponent: 8,
			bytesPerRow: size.width,
			space: CGColorSpaceCreateDeviceGray(),
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		)!
		let oldNsGraphicsContext = NSGraphicsContext.current
		NSGraphicsContext.current = .init(cgContext: cgContext, flipped: false)
		defer { NSGraphicsContext.current = oldNsGraphicsContext }
		
		let image = NSImage(named: "sample")
		image?.draw(in: .init(x: 0, y: 0, width: size.width, height: size.height))
		
		return bytes
	}
	
	//MARK: - View
	
	override func viewDidLoad()
	{
		super.viewDidLoad()
				
		let originalGpuImage = GrayGpuImage(context: gpuContext, size: size)!
		originalGpuImage.replace(
			withGray8Pixels: Self.sampleImageBytes(size: size),
			size: size,
			bytesPerRow: size.width
		)
		self.originalGpuImage = originalGpuImage
		self.workingGpuImage = .init(context: gpuContext, size: size)!
		updateEnabledStates()
	}
	override func viewDidAppear()
	{
		super.viewDidAppear()
		
		reloadImage()
	}
	
	//MARK: - Image Filters
	
	func reloadImage()
	{
		do {
			workingGpuImage.replace(with: originalGpuImage)
			try workingGpuImage.apply(filters: ([
				.level(
					blackLevel: 0.0,
					whiteLevel: 1.0
				),
				.gamma(
					gamma: gammaSlider.doubleValue,
				),
				.gaussianBlur(axis: .x, radius: blurSlider.doubleValue),
				.gaussianBlur(axis: .y, radius: blurSlider.doubleValue),
				((thresholdCheckbox.state == .on) ? .threshold(color: thresholdSlider.doubleValue) : nil),
				.rotate90(turnCount: orientationSlider.integerValue),
			] as [GrayGpuImageBuiltinFilter?]).compactMap { $0 })
			
			imageView.image = .init(cgImage: workingGpuImage.makeCgImage(), size: .zero)
			
		} catch let error {
			NSApp.presentError(error)
		}
	}
	
	//MARK: - View Actions & States
	
	func updateEnabledStates()
	{
		thresholdSlider.isEnabled = (thresholdCheckbox.state == .on)
	}
	
	@IBAction func checkBoxDidChange(_ sender: NSButton)
	{
		reloadImage()
		updateEnabledStates()
	}
	@IBAction func sliderDidChange(_ sender: NSSlider)
	{
		reloadImage()
	}
}

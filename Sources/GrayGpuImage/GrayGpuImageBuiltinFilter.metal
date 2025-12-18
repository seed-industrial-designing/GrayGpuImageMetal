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

#include <metal_stdlib>
using namespace metal;

//MARK: - Color

kernel void level(
	texture2d<float, access::read> inputTexture [[texture(0)]],
	texture2d<float, access::write> outputTexture [[texture(1)]],
	constant float &blackLevel [[buffer(0)]],
	constant float &whiteLevel [[buffer(1)]],
	uint2 gid [[thread_position_in_grid]]
) {
	uint width = inputTexture.get_width();
	uint height = inputTexture.get_height();
	if ((gid.x >= width) || (gid.y >= height)) {
		return;
	}
	float value = inputTexture.read(gid).r;
	value = ((value - blackLevel) / (whiteLevel - blackLevel));
	value = clamp(value, 0.0f, 1.0f);
	outputTexture.write(value, gid);
}
kernel void gamma(
	texture2d<float, access::read> inputTexture [[texture(0)]],
	texture2d<float, access::write> outputTexture [[texture(1)]],
	constant float &gamma [[buffer(0)]],
	uint2 gid [[thread_position_in_grid]]
) {
	uint width = inputTexture.get_width();
	uint height = inputTexture.get_height();
	if ((gid.x >= width) || (gid.y >= height)) {
		return;
	}
	float value = inputTexture.read(gid).r;
	value = pow(value, gamma);
	value = clamp(value, 0.0f, 1.0f);
	outputTexture.write(value, gid);
}

kernel void threshold(
	texture2d<float, access::read> inputTexture [[texture(0)]],
	texture2d<float, access::write> outputTexture [[texture(1)]],
	constant float &color [[buffer(0)]],
	uint2 gid [[thread_position_in_grid]]
) {
	uint width = inputTexture.get_width();
	uint height = inputTexture.get_height();
	if ((gid.x >= width) || (gid.y >= height)) {
		return;
	}
	float value = inputTexture.read(gid).r;
	outputTexture.write(((color < value) ? 1.0f : 0.0f), gid);
}

//MARK: - Blur

kernel void gaussianBlur(
	texture2d<float, access::read> inputTexture [[texture(0)]],
	texture2d<float, access::write> outputTexture [[texture(1)]],
	constant int &axis [[buffer(0)]],
	constant float &sigma [[buffer(1)]],
	uint2 gid [[thread_position_in_grid]]
) {
	uint width = inputTexture.get_width();
	uint height = inputTexture.get_height();
	if ((gid.x >= width) || (gid.y >= height)) {
		return;
	}
	int radius = int(ceil(sigma * 3.0f));
	if (radius == 0) {
		outputTexture.write(inputTexture.read(uint2(gid.x, gid.y)), gid);
	} else {
		float4 sum = float4(0.0f);
		float weightSum = 0.0f;
		
		switch (axis) {
			case 0:
				for (int i = -radius; i <= radius; i += 1) {
					int x = (int(gid.x) + i);
					if ((x < 0) || (x >= int(width))) {
						continue;
					}
					float weight = exp(-(float(i * i)) / (2.0f * sigma * sigma));
					
					float4 pixel = inputTexture.read(uint2(x, gid.y));
					sum += (pixel * weight);
					weightSum += weight;
				}
				break;
			case 1:
				for (int i = -radius; i <= radius; i += 1) {
					int y = (int(gid.y) + i);
					if ((y < 0) || (y >= int(height))) {
						continue;
					}
					float weight = exp(-(float(i * i)) / (2.0f * sigma * sigma));
					
					float4 pixel = inputTexture.read(uint2(gid.x, y));
					sum += (pixel * weight);
					weightSum += weight;
				}
				break;
		}
		outputTexture.write((sum / weightSum), gid);
	}
}

//MARK: - Geometry

kernel void rotate90(
	texture2d<float, access::read> inputTexture [[texture(0)]],
	texture2d<float, access::write> outputTexture [[texture(1)]],
	constant int &turnCount [[buffer(0)]],
	uint2 gid [[thread_position_in_grid]]
) {
	uint inputWidth = inputTexture.get_width();
	uint inputHeight = inputTexture.get_height();
	if ((gid.x >= inputWidth) || (gid.y >= inputHeight)) {
		return;
	}
	uint2 inputCoord;
	switch (turnCount % 4) {
		case 1:
			inputCoord = uint2(gid.y, (inputWidth - 1 - gid.x));
			break;
		case 2:
			inputCoord = uint2((inputWidth - 1 - gid.x), (inputHeight - 1 - gid.y));
			break;
		case 3:
			inputCoord = uint2((inputHeight - 1 - gid.y), gid.x);
			break;
		default:
			inputCoord = gid;
			break;
	}
	float4 color = inputTexture.read(inputCoord);
	outputTexture.write(color, gid);
}

kernel void flip(
	texture2d<float, access::read> inputTexture [[texture(0)]],
	texture2d<float, access::write> outputTexture [[texture(1)]],
	constant int &axis [[buffer(0)]],
	uint2 gid [[thread_position_in_grid]]
) {
	uint inputWidth = inputTexture.get_width();
	uint inputHeight = inputTexture.get_height();
	if ((gid.x >= inputWidth) || (gid.y >= inputHeight)) {
		return;
	}
	uint2 inputCoord;
	switch (axis) {
		case 0:
			inputCoord = uint2((inputWidth - 1 - gid.x), gid.y);
			break;
		case 1:
			inputCoord = uint2(gid.x, (inputHeight - 1 - gid.y));
			break;
	}
	float4 color = inputTexture.read(inputCoord);
	outputTexture.write(color, gid);
}


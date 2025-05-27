# GrayGpuImageMetal

High-performance GPU grayscale image processing for Swift, powered by Metal.

For Windows, [GrayGpuImageSharp](https://github.com/seed-industrial-designing/GrayGpuImageSharp) is also available.

## Examples

### Applying filters

In the following example, the function applies filters to 8-bit gray pixels and returns `CGImage`.

```swift
func blur(gray8Pixels: [UInt8], size: (width: Int, height: Int), bytesPerRow: Int, radius: Double) throws -> CGImage
{
    var gpuContext = try GrayGpuContext()
    let gpuImage = GrayGpuImage(context: gpuContext, size: size)!
    gpuImage.replace(
        withGray8Pixels: gray8Pixels,
        size: size,
        bytesPerRow: bytesPerRow
    )
    try gpuImage.apply(filters: ([
        .gaussianBlur(axis: .x, radius: radius),
        .gaussianBlur(axis: .y, radius: radius),
    ] as [GrayGpuImageBuiltinFilter]))
    
    return gpuImage.makeCgImage()
}
```

If the processing is frequent, reuse instances of `GrayGpuContext` and `GrayGpuImage` for better performance.

### Define your own filters

You can define your own filters as `enum` by using `@GrayGpuImageFilter` macro.

```swift
@GrayGpuImageFilter enum MyFilter
{
    case doSomething(factor: Double)
}
```

```metal
#include <metal_stdlib>
using namespace metal;

kernel void doSomething(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float &factor [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float inputValue = inputTexture.read(gid).r;
    float outputValue = (inputValue * factor);
    
    outputTexture.write(outputValue, gid);
}
```

## License

GrayGpuImageMetal is released under the [MIT License](LICENSE.txt).

/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that draws the frames of two cameras into one frame with Metal.
*/

import CoreMedia
import CoreVideo
import Metal

/// An object that draws a small picture from one camera into the full picture of the other camera.
///
/// The mixer runs a Metal compute kernel for each frame. `DualRecorder` calls it on the data output queue.
final class PiPVideoMixer {
    
    /// The parameters that the kernel reads. The layout must match the `MixerParameters` struct in the shader.
    private struct MixerParameters {
        var smallPicturePosition: SIMD2<Float>
        var smallPictureSize: SIMD2<Float>
    }
    
    /// The frame of the small picture, as a part of the full picture (0 to 1 in each direction).
    var smallPictureFrame = CGRect(x: 0.04, y: 0.03, width: 0.3, height: 0.3)
    
    /// A Boolean value that indicates whether the mixer has a buffer pool for the current frame size.
    private(set) var isPrepared = false
    
    /// The format of the frames that the mixer produces.
    private(set) var outputFormatDescription: CMFormatDescription?
    
    private let device = MTLCreateSystemDefaultDevice()
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLComputePipelineState?
    private var textureCache: CVMetalTextureCache?
    private var outputPool: CVPixelBufferPool?
    
    init() {
        // Compile the kernel one time. The default library contains every `.metal` file of the target.
        guard let device, let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "pictureInPictureMixer") else { return }
        commandQueue = device.makeCommandQueue()
        pipelineState = try? device.makeComputePipelineState(function: function)
    }
    
    // MARK: - Preparation
    
    /// Creates a pixel buffer pool and a texture cache for frames of the given format.
    func prepare(with formatDescription: CMFormatDescription) {
        reset()
        guard let device else { return }
        
        // The output frames have the size and the pixel format of the input frames.
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(dimensions.width),
            kCVPixelBufferHeightKey as String: Int(dimensions.height),
            // An IOSurface lets Metal and the asset writer share the buffer without a copy.
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        var pool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess, let pool else { return }
        outputPool = pool
        
        // Describe the output format from a first buffer of the pool.
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }
        var description: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: buffer, formatDescriptionOut: &description)
        outputFormatDescription = description
        
        // The cache turns pixel buffers into Metal textures without a copy.
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        textureCache = cache
        
        isPrepared = outputFormatDescription != nil && textureCache != nil
    }
    
    /// Discards the buffer pool and the texture cache.
    func reset() {
        outputPool = nil
        outputFormatDescription = nil
        textureCache = nil
        isPrepared = false
    }
    
    // MARK: - Mixing
    
    /// Returns a new frame with the small picture drawn into the full picture.
    func mix(fullPicture: CVPixelBuffer, smallPicture: CVPixelBuffer) -> CVPixelBuffer? {
        guard isPrepared, let outputPool, let commandQueue, let pipelineState else { return nil }
        
        // Take a buffer from the pool. The pool reuses buffers that the writer has released.
        var output: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, outputPool, &output)
        guard let output,
              let fullTexture = makeTexture(from: fullPicture),
              let smallTexture = makeTexture(from: smallPicture),
              let outputTexture = makeTexture(from: output) else { return nil }
        
        // Convert the normalized frame of the small picture to pixels of the output.
        var parameters = MixerParameters(
            smallPicturePosition: SIMD2(Float(smallPictureFrame.minX) * Float(outputTexture.width),
                                        Float(smallPictureFrame.minY) * Float(outputTexture.height)),
            smallPictureSize: SIMD2(Float(smallPictureFrame.width) * Float(outputTexture.width),
                                    Float(smallPictureFrame.height) * Float(outputTexture.height)))
        
        // Encode one run of the kernel over every pixel of the output.
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(fullTexture, index: 0)
        encoder.setTexture(smallTexture, index: 1)
        encoder.setTexture(outputTexture, index: 2)
        encoder.setBytes(&parameters, length: MemoryLayout<MixerParameters>.size, index: 0)
        
        // Split the output into thread groups that fit the GPU.
        let width = pipelineState.threadExecutionWidth
        let height = pipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSize(width: width, height: height, depth: 1)
        let groups = MTLSize(width: (outputTexture.width + width - 1) / width,
                             height: (outputTexture.height + height - 1) / height,
                             depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        // Wait for the GPU, so that the frame is complete when the writer reads it.
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return output
    }
    
    /// Wraps a pixel buffer in a Metal texture through the texture cache.
    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache else { return nil }
        var texture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm,
                                                  CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer),
                                                  0, &texture)
        guard let texture else { return nil }
        return CVMetalTextureGetTexture(texture)
    }
}

//
//  PersonSegmentationHandler.swift
//  MetalCamera
//
//  Created by  Eric on 2022/01/12.
//

import AVFoundation
import CoreImage.CIFilterBuiltins
import Vision

var isFirstTime = true

public class PersonSegmentationHandler: CMSampleChain {
    public var targets = TargetContainer<OperationChain>()

    private var isProcessing = false
    
    public var runBenchmark = true
    private let requestHandler = VNSequenceRequestHandler()
    private let segmentationRequest: VNGeneratePersonSegmentationRequest
    
    private var currentTime = CMTime.zero
    private var startTime: CFAbsoluteTime = 0
    private var frameTexture: Texture?
    
    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!
    
    let resultOperation = AlphaBlend()
    
    public init() {
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
    
    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "segmentation_render_target2", colorPixelFormat)
            pipelineState = try sharedMetalRenderingDevice.device.makeRenderPipelineState(descriptor: rpd)

            render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(size: CGSize(width: width, height: height))
            render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(CGSize(width: width, height: height))
        } catch {
            debugPrint(error)
        }
    }
                    
    public func newTextureAvailable(_ texture: Texture) {
        if currentTime == texture.timestamp {
            frameTexture = texture
        }
    }
    
    public func newBufferAvailable(_ sampleBuffer: CMSampleBuffer) {
        if isProcessing {
            if runBenchmark {
                debugPrint("Drop the frame....")
            }

            return
        }

        isProcessing = true
        
        defer {
            isProcessing = false
        }
        
        currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        startTime = CFAbsoluteTimeGetCurrent()
                        
        guard let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        
        do {
            try requestHandler.perform([segmentationRequest], on: cameraFrame)
            guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                return
            }
                        
            guard let outputTexture = generateTexture(maskPixelBuffer) else {
                return
            }
            
            operationFinished(outputTexture)
            return
                        
            guard let frameTexture = frameTexture else {
                return
            }
            
            resultOperation.newTextureAvailable(frameTexture, outputTexture) { [weak self] (texture) in
                self?.operationFinished(texture)
            }
            
//            let texture: Texture?
//            let bufferWidth = CVPixelBufferGetWidth(maskPixelBuffer)
//            let bufferHeight = CVPixelBufferGetHeight(maskPixelBuffer)
//            let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
//
//            var textureRef: CVMetalTexture? = nil
//
//            let _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache, maskPixelBuffer, nil, .r8Uint, bufferWidth, bufferHeight , 0, &textureRef)
//            if let concreteTexture = textureRef,
//                let cameraTexture = CVMetalTextureGetTexture(concreteTexture) {
//                texture = Texture(texture: cameraTexture, timestamp: currentTime, textureKey: "Segmentation")
//            } else {
//                texture = nil
//            }
//
//            if let texture = texture {
//                self.operationFinished(texture)
//            }

            isProcessing = false
        } catch {
            debugPrint("\(error.localizedDescription)")
        }
    }
    

    
    private func generateTexture(_ mask: CVPixelBuffer) -> Texture? {
        
        CVPixelBufferLockBaseAddress(mask, CVPixelBufferLockFlags(rawValue: 0))
        
        defer {
            CVPixelBufferUnlockBaseAddress(mask, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        let bufferWidth = CVPixelBufferGetWidth(mask)
        let bufferHeight = CVPixelBufferGetHeight(mask)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else {
            return nil
        }
        
        if pipelineState == nil {
            setupPiplineState(width: bufferWidth, height: bufferHeight)
        }
        
        let outputTexture = Texture(bufferWidth, bufferHeight, timestamp: currentTime, textureKey: "segmentation")

        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.clearColor = MTLClearColorMake(1, 0, 0, 1)
        attachment?.texture = outputTexture.texture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store

        let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        commandEncoder?.setRenderPipelineState(pipelineState)

        commandEncoder?.setVertexBuffer(render_target_vertex, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(render_target_uniform, offset: 0, index: 1)
        

        let segmentationBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: baseAddress,
                                                                              length: bufferWidth * bufferHeight * MemoryLayout<UInt8>.size,
                                                                              options: [])!
        commandEncoder?.setFragmentBuffer(segmentationBuffer, offset: 0, index: 0)
        
        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: [Int32(255), Int32(bufferWidth), Int32(bufferHeight)] as [Int32],
                                                                         length: 3 * MemoryLayout<Int32>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        
        return outputTexture
    }
    
    private func printPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        for i in 0..<bufferWidth*bufferHeight {
            if buffer[i] != 0 {
                print(buffer[i])
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
}


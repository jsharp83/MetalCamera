//
//  PersonSegmentationHandler.swift
//  MetalCamera
//
//  Created by  Eric on 2022/01/12.
//

import AVFoundation
import Vision

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
    
    let processingQueue = DispatchQueue.global()
    
    public init() {
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
    
    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "segmentation_resize_render_target", colorPixelFormat)
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
    
    private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        startTime = CFAbsoluteTimeGetCurrent()
                        
        guard let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        do {
            try requestHandler.perform([segmentationRequest], on: cameraFrame)
            guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                return
            }
                        
            let bufferWidth = CVPixelBufferGetWidth(cameraFrame)
            let bufferHeight = CVPixelBufferGetHeight(cameraFrame)
            
            guard let outputTexture = generateTexture(maskPixelBuffer, bufferWidth, bufferHeight) else {
                return
            }
            
            let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
                        
            guard let frameTexture = frameTexture else {
                return
            }
            
            resultOperation.newTextureAvailable(frameTexture, outputTexture) { [weak self] (texture) in
                self?.operationFinished(texture)
            }
            
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            if runBenchmark {
                debugPrint("Current inferenceTime: \(1000.0 * inferenceTime)ms, totalTime: \(1000.0 * totalTime)ms")
            }
            
            isProcessing = false
        } catch {
            debugPrint("\(error.localizedDescription)")
        }
    }
    
    public func newBufferAvailable(_ sampleBuffer: CMSampleBuffer) {
        if isProcessing {
            if runBenchmark {
                debugPrint("Drop the frame....")
            }

            return
        }

        processingQueue.async { [weak self] in
            self?.handleSampleBuffer(sampleBuffer)
        }
    }
    

    
    private func generateTexture(_ mask: CVPixelBuffer, _ targetWidth: Int, _ targetHeight: Int) -> Texture? {
        
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
            setupPiplineState(width: targetWidth, height: targetHeight)
        }
        
        let outputTexture = Texture(targetWidth, targetHeight, timestamp: currentTime, textureKey: "segmentation")

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
        
        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: [Float32(bufferWidth), Float32(bufferHeight), Float32(Float32(bufferWidth)/Float32(targetWidth)), Float32(Float32(bufferHeight)/Float32(targetHeight))] as [Float32],
                                                                         length: 4 * MemoryLayout<Float32>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        
        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        
        return outputTexture
    }
}


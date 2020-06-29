//
//  CoreMLHandler.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/12.
//

import Foundation
import AVFoundation
import CoreML
import Vision

public class CoreMLClassifierHandler: CMSampleChain {
    public var targets = TargetContainer<OperationChain>()
    let visionModel: VNCoreMLModel
    let imageCropAndScaleOption: VNImageCropAndScaleOption
    var request: VNCoreMLRequest?
    let dropFrame: Bool
    var isProcessing: Bool = false
    var currentTime = CMTime.zero
    var startTime: CFAbsoluteTime = 0
    var frameTexture: Texture?
    let blender = AlphaBlend()

    // TODO: I need to make benchmark module.
    public var runBenchmark = true

    var colorBuffer: MTLBuffer?
    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    public init(_ model: MLModel, imageCropAndScaleOption: VNImageCropAndScaleOption = .centerCrop, dropFrame: Bool = true, maxClasses: Int = 255) throws {
        self.visionModel = try VNCoreMLModel(for: model)
        self.imageCropAndScaleOption = imageCropAndScaleOption
        self.dropFrame = dropFrame

        if maxClasses > randomColors.count {
            randomColors = generateRandomColors(maxClasses)
        }
    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "segmentation_render_target", colorPixelFormat)
            pipelineState = try sharedMetalRenderingDevice.device.makeRenderPipelineState(descriptor: rpd)

            render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(size: CGSize(width: width, height: height))
            render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(CGSize(width: width, height: height))
        } catch {
            debugPrint(error)
        }
    }

    public func newBufferAvailable(_ sampleBuffer: CMSampleBuffer) {
        if dropFrame, isProcessing {
            if runBenchmark {
                debugPrint("Drop the frame....")
            }

            return
        }

        isProcessing = true

        currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        startTime = CFAbsoluteTimeGetCurrent()

        guard let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // FIXME: Refactoring is needed. I don't know it is needed to keep the reqeust.
        let request = self.request != nil ? self.request! : createRequest()
        self.request = request

        let handler = VNImageRequestHandler(cvPixelBuffer: cameraFrame, options: [:])
        DispatchQueue.global().async {
            try? handler.perform([request])
        }
    }

    func generateTexture(_ segmentationMap: MLMultiArray, _ row: Int, _ col: Int, _ targetClass: Int) -> Texture? {
        if pipelineState == nil {
            setupPiplineState(width: col, height: row)
        }

        let outputTexture = Texture(col, row, timestamp: currentTime, textureKey: "segmentation")

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

        let segmentationBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: segmentationMap.dataPointer,
                                                                              length: segmentationMap.count * MemoryLayout<Int32>.size,
                                                                              options: [])!
        commandEncoder?.setFragmentBuffer(segmentationBuffer, offset: 0, index: 0)

        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: [Int32(targetClass), Int32(col), Int32(row)] as [Int32],
                                                                         length: 3 * MemoryLayout<Int32>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)

        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()

        return outputTexture
    }

    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime

        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let segmenationMap = observations.first?.featureValue.multiArrayValue {

            if runBenchmark {
                debugPrint("Request Complete")
            }

            guard let row = segmenationMap.shape[0] as? Int,
                let col = segmenationMap.shape[1] as? Int else {
                    return
            }

            guard let frameTexture = frameTexture else { return }

            let targetClass = 15 // Human

            guard let outputTexture = generateTexture(segmenationMap, row, col, targetClass) else { return }

            blender.newTextureAvailable(frameTexture, overlay: outputTexture) { [weak self](texture) in
                self?.operationFinished(texture)
            }
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        if runBenchmark {
            debugPrint("Current inferenceTime: \(1000.0 * inferenceTime)ms, totalTime: \(1000.0 * totalTime)ms")
        }

        self.isProcessing = false
    }

    func createRequest() -> VNCoreMLRequest {
        let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete(request:error:))
        request.imageCropAndScaleOption = imageCropAndScaleOption
        return request
    }

    public func newTextureAvailable(_ texture: Texture) {
        if currentTime == texture.timestamp {
            frameTexture = texture
        }
    }
}

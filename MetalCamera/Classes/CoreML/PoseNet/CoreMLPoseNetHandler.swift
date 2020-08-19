//
//  CoreMLPoseNetHandler.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/29.
//

import Foundation
import AVFoundation
import CoreML
import Vision

public class CoreMLPoseNetHandler: CMSampleChain {
    public var targets = TargetContainer<OperationChain>()
    let visionModel: VNCoreMLModel
    let imageCropAndScaleOption: VNImageCropAndScaleOption
    var request: VNCoreMLRequest?
    let dropFrame: Bool
    var isProcessing: Bool = false
    var currentTime = CMTime.zero
    var startTime: CFAbsoluteTime = 0
    var frameTexture: Texture?

    // TODO: I need to make benchmark module.
    public var runBenchmark = true

    var colorBuffer: MTLBuffer?
    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    public init(_ model: MLModel, imageCropAndScaleOption: VNImageCropAndScaleOption = .scaleFill, dropFrame: Bool = true) throws {
        self.visionModel = try VNCoreMLModel(for: model)
        self.imageCropAndScaleOption = imageCropAndScaleOption
        self.dropFrame = dropFrame
    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "posenet_render_target", colorPixelFormat)
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

    func generateTexture(_ posenet: PoseNetOutput) -> Texture? {
        guard let frameTexture = frameTexture else { return nil }
        if pipelineState == nil {
            setupPiplineState(width: frameTexture.texture.width, height: frameTexture.texture.height)
        }

        let outputTexture = Texture(frameTexture.texture.width, frameTexture.texture.height, timestamp: currentTime, textureKey: "posenet")

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

        let posenetBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: posenet.heatmap.dataPointer,
                                                                         length: posenet.heatmap.count * MemoryLayout<Double>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(posenetBuffer, offset: 0, index: 0)

        let shape = posenet.heatmap.shape

        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: [Int32(shape[0]), Int32(shape[1]), Int32(shape[2])] as [Int32],
                                                                         length: 3 * MemoryLayout<Int32>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        commandEncoder?.setFragmentTexture(frameTexture.texture, index: 0)

        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()

        let startTime2 = CFAbsoluteTimeGetCurrent()
        let pose = Pose()

        for name in Joint.Name.allCases {
            let joint = pose.joints[name]!

            var bestCell = PoseNetOutput.Cell(0, 0)
            var bestConfidence = 0.0
            for yIndex in 0..<posenet.height {
                for xIndex in 0..<posenet.width {
                    let currentCell = PoseNetOutput.Cell(yIndex, xIndex)
                    let currentConfidence = posenet.confidence(for: joint.name, at: currentCell)

                    // Keep track of the cell with the greatest confidence.
                    if currentConfidence > bestConfidence {
                        bestConfidence = currentConfidence
                        bestCell = currentCell
                    }
                }
            }
//            print("\(bestCell), \(bestConfidence)")
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime2
        debugPrint("Current totalTime: \(1000.0 * totalTime)ms")

        return outputTexture
    }

    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime

        if let observations = request.results as? [VNCoreMLFeatureValueObservation] {
            let output = PoseNetOutput(observations)

            guard let outputTexture = generateTexture(output) else { return }

            operationFinished(outputTexture)

            let totalTime = CFAbsoluteTimeGetCurrent() - startTime

            if runBenchmark {
//                debugPrint("Current inferenceTime: \(1000.0 * inferenceTime)ms, totalTime: \(1000.0 * totalTime)ms")
            }

            self.isProcessing = false
        }
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

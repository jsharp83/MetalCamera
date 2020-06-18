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
    public var runBenchmark = false

    public init(_ model: MLModel, imageCropAndScaleOption: VNImageCropAndScaleOption = .centerCrop, dropFrame: Bool = true, maxClasses: Int = 255) throws {
        self.visionModel = try VNCoreMLModel(for: model)
        self.imageCropAndScaleOption = imageCropAndScaleOption
        self.dropFrame = dropFrame

        if maxClasses > randomColors.count {
            randomColors = generateRandomColors(maxClasses)
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

            let outputTexture = Texture(col, row, timestamp: currentTime, textureKey: "camera")

            var dataBuffer = [UInt8]()

            // FIXME: I think there is better solution to use MLMultiArray's dataPointer than creating new dataBuffer.
            for r in 0..<row {
                for c in 0..<col {
                    let index = r * col + c

                    guard let classNum = segmenationMap[index] as? Int else {
                        return
                    }
                    let classColor = randomColors[classNum]
                    dataBuffer.append(contentsOf: classColor)
                }
            }

            let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: col, height: row, depth: 1))
            outputTexture.texture.replace(region: region, mipmapLevel: 0, withBytes: dataBuffer, bytesPerRow: 4 * col)

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

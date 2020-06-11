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
            debugPrint("Drop the frame....")
            return
        }

        isProcessing = true

        guard let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // FIXME: Refactoring is needed. I don't know it is needed to keep the reqeust.
        let request = self.request != nil ? self.request! : createRequest()
        self.request = request

        let handler = VNImageRequestHandler(cvPixelBuffer: cameraFrame, options: [:])
        try? handler.perform([request])
    }

    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let segmenationMap = observations.first?.featureValue.multiArrayValue {
            debugPrint("Request Complete")
        }

        self.isProcessing = false
    }

    func createRequest() -> VNCoreMLRequest {
        let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete(request:error:))
        request.imageCropAndScaleOption = imageCropAndScaleOption
        return request
    }

    public func newTextureAvailable(_ texture: Texture) {}
}

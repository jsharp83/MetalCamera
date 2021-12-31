//
//  TranslationHandler.swift
//  MetalCamera
//
//  Created by  Eric on 2021/12/31.
//

import AVFoundation
import Vision

public class TranslationHandler: CMSampleChain {    
    public var targets = TargetContainer<OperationChain>()

    private var previousSampleBuffer: CMSampleBuffer?
    private var isProcessing = false
    
    public var runBenchmark = true
    public var translationCallback: ((CGAffineTransform) -> Void)?
    
    private let sceneStabilityRequestHandler = VNSequenceRequestHandler()
    
    public init() {}
            
    public func newTextureAvailable(_ texture: Texture) {
        self.operationFinished(texture)
    }
    
    public func newBufferAvailable(_ sampleBuffer: CMSampleBuffer) {
        guard let previousBuffer = self.previousSampleBuffer else {
            self.previousSampleBuffer = sampleBuffer
            return
        }
        
        if isProcessing {
            if runBenchmark {
                debugPrint("Drop the frame....")
            }

            return
        }

        isProcessing = true
        
        let registrationRequest = VNTranslationalImageRegistrationRequest(targetedCMSampleBuffer: sampleBuffer)
        
        do {
            try sceneStabilityRequestHandler.perform([registrationRequest], on: previousBuffer)
            if let alignmentObservation = registrationRequest.results?.first {
                let transform = alignmentObservation.alignmentTransform
                translationCallback?(transform)
            }
        } catch {
            debugPrint("\(error.localizedDescription)")
        }
        
        self.previousSampleBuffer = sampleBuffer
        isProcessing = false
    }
}

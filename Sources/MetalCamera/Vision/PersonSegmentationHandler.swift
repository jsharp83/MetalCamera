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
    
    public init() {
        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .balanced
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }
            
    public func newTextureAvailable(_ texture: Texture) {
        self.operationFinished(texture)
    }
    
    public func newBufferAvailable(_ sampleBuffer: CMSampleBuffer) {
        if isProcessing {
            if runBenchmark {
                debugPrint("Drop the frame....")
            }

            return
        }

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
        
        isProcessing = true
        
        defer {
            isProcessing = false
        }
        
        do {
            try requestHandler.perform([segmentationRequest], on: pixelBuffer)
            guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else {
                return
            }
            
        } catch {
            debugPrint("\(error.localizedDescription)")
        }
    }
}


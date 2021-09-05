//
//  AudioCompositor.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/08.
//

import Foundation
import AVFoundation

class AudioCompositor: AudioOperationChain {
    public var audioTargets = TargetContainer<AudioOperationChain>()
    public let mainSourceKey: String
    public var preservedBuffer: AudioBuffer?


    public init(_ mainSourceKey: String) {
        self.mainSourceKey = mainSourceKey
    }

    public func newAudioAvailable(_ sampleBuffer: AudioBuffer) {
        if sampleBuffer.key == mainSourceKey {
            audioOperationFinished(sampleBuffer)
//            playSampleBuffer(sampleBuffer)
//            if let preservedBuffer = preservedBuffer {
//                audioOperationFinished(sampleBuffer)
//                self.preservedBuffer = nil
//            } else {
//                audioOperationFinished(sampleBuffer)
//            }
        } else {
//            preservedBuffer = sampleBuffer
//            playSampleBuffer(sampleBuffer)
        }
    }

//    func playSampleBuffer(_ sampleBuffer: AudioBuffer) {
//        let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer.buffer)
//        let blockBufferDataLength = CMBlockBufferGetDataLength(blockBuffer!)
//
//        var blockBufferData  = [UInt8](repeating: 0, count: blockBufferDataLength)
//        let status = CMBlockBufferCopyDataBytes(blockBuffer!, 0, blockBufferDataLength, &blockBufferData)
//        guard status == noErr else { return }
//        let data = Data(bytes: blockBufferData, count: blockBufferDataLength)
//
//    }
}

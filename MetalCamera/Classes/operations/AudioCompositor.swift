//
//  AudioCompositor.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/08.
//

import Foundation
import AVFoundation

public class AudioCompositor: AudioOperationChain {
    public var audioTargets = TargetContainer<AudioOperationChain>()

    public func newAudioAvailable(_ sampleBuffer: AudioBuffer) {

    }
}

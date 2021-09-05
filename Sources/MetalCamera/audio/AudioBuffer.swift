//
//  AudioBuffer.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/08.
//

import Foundation
import AVFoundation

public class AudioBuffer {
    let buffer: CMSampleBuffer
    let key: String

    public init(_ buffer: CMSampleBuffer, _ key: String = "") {
        self.buffer = buffer
        self.key = key
    }
}

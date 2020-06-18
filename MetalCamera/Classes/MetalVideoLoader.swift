//
//  MetalVideoLoader.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import Foundation
import AVFoundation

public class MetalVideoLoader: OperationChain, AudioOperationChain {
    public let sourceKey: String
    public var targets = TargetContainer<OperationChain>()
    public var audioTargets = TargetContainer<AudioOperationChain>()

    private let asset: AVAsset
    private var assetReader: AVAssetReader!
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private var audioTrackOutput: AVAssetReaderTrackOutput?
    private let loop: Bool
    private let playAtActualSpeed: Bool
    private let useAudio: Bool

    private var previousFrameTime = CMTime.zero
    private var previousActualFrameTime = CFAbsoluteTimeGetCurrent()

    private var videoTextureCache: CVMetalTextureCache?

    public convenience init(url: URL, playAtActualSpeed: Bool = true, loop: Bool = true, sourceKey: String = "video", useAudio: Bool = false) throws {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        try self.init(asset: asset, playAtActualSpeed: playAtActualSpeed, loop: loop, useAudio: useAudio)
    }

    public init(asset: AVAsset, playAtActualSpeed: Bool = true, loop: Bool = true, sourceKey: String = "video", useAudio: Bool = false) throws {
        self.asset = asset
        self.loop = loop
        self.playAtActualSpeed = playAtActualSpeed
        self.sourceKey = sourceKey
        self.useAudio = useAudio

        let _ = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, sharedMetalRenderingDevice.device, nil, &videoTextureCache)
        try createAssetReader()
    }

    func createAssetReader() throws {
        assetReader = try AVAssetReader(asset: self.asset)

        let outputSettings: [String: Any] =  [kCVPixelBufferMetalCompatibilityKey as String: true,
                                              kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let videoTrackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
            assetReader.add(videoTrackOutput)
            self.videoTrackOutput = videoTrackOutput
        } else {
            self.videoTrackOutput = nil
        }

        guard useAudio else { return }

        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let outputSettings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM,
                                                 AVNumberOfChannelsKey: 1,
                                                 AVSampleRateKey: 44100,
            ]

            let audioTrackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            assetReader.add(audioTrackOutput)
            self.audioTrackOutput = audioTrackOutput
        } else {
            self.audioTrackOutput = nil
        }
    }

    public func start() {
        if assetReader.status == .cancelled {
            restart()
            return
        }

        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            DispatchQueue.global().async {
                guard (self.asset.statusOfValue(forKey: "tracks", error: nil) == .loaded) else {
                    return
                }

                guard self.assetReader.startReading() else {
                    debugPrint("Couldn't start reading")
                    return
                }

                self.processReadingTrack()
            }
        }
    }

    public func stop() {
        assetReader.cancelReading()
    }

    private func processReadingTrack() {
        while assetReader.status == .reading {
            if let videoTrackOutput = videoTrackOutput {
                readNextVideoFrame(from: videoTrackOutput)
            }
            if let audioTrackOutput = audioTrackOutput {
                readNextAudioFrame(from: audioTrackOutput)
            }
        }

        if assetReader.status == .completed && loop {
            assetReader.cancelReading()
            restart()
        }
    }

    private func restart() {
        do {
            try createAssetReader()
            start()
        } catch {
            debugPrint(error)
        }
    }

    private func readNextVideoFrame(from videoTrackOutput: AVAssetReaderOutput) {
        guard assetReader.status == .reading else { return }

        if let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
            if playAtActualSpeed {
                let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                let differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime)
                let currentActualTime = CFAbsoluteTimeGetCurrent()

                let frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame)
                let actualTimeDifference = currentActualTime - previousActualFrameTime

                if (frameTimeDifference > actualTimeDifference) {
                    usleep(UInt32(round(1000000.0 * (frameTimeDifference - actualTimeDifference))))
                }

                previousFrameTime = currentSampleTime
                previousActualFrameTime = CFAbsoluteTimeGetCurrent()
            }

            debugPrint("Read Video frame")
            process(sampleBuffer)
            CMSampleBufferInvalidate(sampleBuffer)
        }
    }

    private func readNextAudioFrame(from audioTrackOutput: AVAssetReaderOutput) {
        guard assetReader.status == .reading else { return }

        if let sampleBuffer = audioTrackOutput.copyNextSampleBuffer() {
            debugPrint("Read Audio frame")
            audioOperationFinished(AudioBuffer(sampleBuffer, sourceKey))
            CMSampleBufferInvalidate(sampleBuffer)
        }
    }

    private func process(_ frame:CMSampleBuffer) {
        guard let videoTextureCache = videoTextureCache else { return }

        let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(frame)
        let movieFrame = CMSampleBufferGetImageBuffer(frame)!

        let bufferHeight = CVPixelBufferGetHeight(movieFrame)
        let bufferWidth = CVPixelBufferGetWidth(movieFrame)

        CVPixelBufferLockBaseAddress(movieFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
        let texture:Texture?
        var textureRef: CVMetalTexture? = nil

        let _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache, movieFrame, nil, .bgra8Unorm, bufferWidth, bufferHeight, 0, &textureRef)
        if let concreteTexture = textureRef,
            let cameraTexture = CVMetalTextureGetTexture(concreteTexture) {
            texture = Texture(texture: cameraTexture, timestamp: currentSampleTime, textureKey: self.sourceKey)
        } else {
            texture = nil
        }

        CVPixelBufferUnlockBaseAddress(movieFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))

        if let texture = texture {
            operationFinished(texture)
        }
    }

    public func newTextureAvailable(_ texture: Texture) {}
    public func newAudioAvailable(_ sampleBuffer: AudioBuffer) {}
}


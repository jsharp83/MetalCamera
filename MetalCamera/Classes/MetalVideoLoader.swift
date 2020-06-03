//
//  MetalVideoLoader.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import Foundation
import AVFoundation

public class MetalVideoLoader: OperationChain {
    public let textureKey: String
    public var targets = TargetContainer<OperationChain>()

    private let asset: AVAsset
    private var assetReader: AVAssetReader!
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private let loop: Bool
    private let playAtActualSpeed: Bool

    private var previousFrameTime = kCMTimeZero
    private var previousActualFrameTime = CFAbsoluteTimeGetCurrent()

    private var videoTextureCache: CVMetalTextureCache?

    public convenience init(url: URL, playAtActualSpeed: Bool = true, loop: Bool = true, textureKey: String = "video") throws {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        try self.init(asset: asset, playAtActualSpeed: playAtActualSpeed, loop: loop)
    }

    public init(asset: AVAsset, playAtActualSpeed: Bool = true, loop: Bool = true, textureKey: String = "video") throws {
        self.asset = asset
        self.loop = loop
        self.playAtActualSpeed = playAtActualSpeed
        self.textureKey = textureKey

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

            process(sampleBuffer)
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
            texture = Texture(texture: cameraTexture, timestamp: currentSampleTime, textureKey: self.textureKey)
        } else {
            texture = nil
        }

        CVPixelBufferUnlockBaseAddress(movieFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))

        if let texture = texture {
            operationFinished(texture)
        }
    }

    public func newTextureAvailable(_ texture: Texture) {

    }
}


//
//  MetalVideoWriter.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import Foundation
import AVFoundation
import CoreImage

public class MetalVideoWriter: OperationChain, AudioOperationChain {
    public var targets = TargetContainer<OperationChain>()
    public var audioTargets = TargetContainer<AudioOperationChain>()

    private var isRecording = false
    private var startTime: CMTime?
    private var previousFrameTime = kCMTimeNegativeInfinity
    private var previousAudioTime = kCMTimeNegativeInfinity

    private let assetWriter: AVAssetWriter
    private let assetWriterVideoInput: AVAssetWriterInput
    private let assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor

    private let assetWriterAudioInput: AVAssetWriterInput?

    private let url: URL
    private let videoSize: CGSize

    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    private let textureInputSemaphore = DispatchSemaphore(value:1)

    let ciContext = CIContext(mtlDevice: sharedMetalRenderingDevice.device, options: nil)

    private let recordAudio: Bool

    public init(url: URL, videoSize: CGSize, fileType: AVFileType = .mov, settings: [String: Any]? = nil, recordAudio: Bool = false) throws {
        assetWriter = try AVAssetWriter(url: url, fileType: fileType)
        self.videoSize = videoSize
        self.url = url
        self.recordAudio = recordAudio

        // Setup Video
        let localSettings: [String: Any]

        if let settings = settings {
            localSettings = settings
        } else {
            localSettings = [AVVideoCodecKey: AVVideoCodecType.h264,
                             AVVideoWidthKey: videoSize.width,
                             AVVideoHeightKey: videoSize.height ]
        }

        assetWriterVideoInput = AVAssetWriterInput(mediaType:AVMediaType.video, outputSettings:localSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2300000
            ]]

        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput,
                                                                           sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        assetWriter.add(assetWriterVideoInput)

        // Setup Audio
        if recordAudio {
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 44100,
                AVEncoderBitRateKey: 64000
            ])

            audioInput.expectsMediaDataInRealTime = true
            if assetWriter.canAdd(audioInput) {
                assetWriter.add(audioInput)
            }

            assetWriterAudioInput = audioInput
        } else {
            assetWriterAudioInput = nil
        }

        setupPiplineState()
        loadRenderTargetVertex(videoSize)
    }

    public func startRecording() {
        self.startTime = nil
        self.isRecording = self.assetWriter.startWriting()
    }

    public func finishRecording(_ completionCallback:(() -> Void)? = nil) {
        self.isRecording = false

        if (self.assetWriter.status == .completed || self.assetWriter.status == .cancelled || self.assetWriter.status == .unknown) {
            DispatchQueue.global().async{
                completionCallback?()
            }
            return
        }

        self.assetWriterVideoInput.markAsFinished()
        self.assetWriter.finishWriting {
            completionCallback?()
            debugPrint("Write finished!!")
        }
    }

    private func setupVideo() {

    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "fragment_render_target", colorPixelFormat)
            pipelineState = try sharedMetalRenderingDevice.device.makeRenderPipelineState(descriptor: rpd)
        } catch {
            debugPrint(error)
        }
    }

    private func loadRenderTargetVertex(_ baseTextureSize: CGSize) {
        render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(size: baseTextureSize)
        render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(baseTextureSize)
    }
}

// MARK: Video processing
extension MetalVideoWriter {
    public func newTextureAvailable(_ texture: Texture) {
        DispatchQueue.main.sync {

            guard isRecording else { return }

            guard let frameTime = texture.timestamp else { return }

            let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
            defer {
                textureInputSemaphore.signal()
            }

            if startTime == nil {
                assetWriter.startSession(atSourceTime: frameTime)
                startTime = frameTime
            }

            guard assetWriterVideoInput.isReadyForMoreMediaData,
                let inputPixelBufferPool = assetWriterPixelBufferInput.pixelBufferPool else {
                    debugPrint("Had to drop a frame at time \(frameTime)")
                    return
            }

            var pixelBufferFromPool: CVPixelBuffer? = nil
            let pixelBufferStatus = CVPixelBufferPoolCreatePixelBuffer(nil, inputPixelBufferPool, &pixelBufferFromPool)
            guard let pixelBuffer = pixelBufferFromPool, (pixelBufferStatus == kCVReturnSuccess) else { return }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])

            // FIXME: Has problem with Color format and orientation.
            let kciOptions = [kCIImageColorSpace: CGColorSpaceCreateDeviceRGB(),
                              kCIContextOutputPremultiplied: true,
                              kCIContextUseSoftwareRenderer: false] as [String : Any]
            var ciImage = CIImage(mtlTexture: texture.texture, options: kciOptions)
            ciImage = ciImage?.oriented(.downMirrored)
            ciContext.render(ciImage!, to: pixelBuffer)

            // FIXME: Want to fix rednerIntoPixelBuffer func rather than using CIFilter.
            //                    renderIntoPixelBuffer(pixelBuffer, texture:texture)
            if (!assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime:frameTime)) {
                debugPrint("Problem appending pixel buffer at time: \(frameTime)")
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))

            textureInputSemaphore.signal()
            operationFinished(texture)
            let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        }
    }

    func renderIntoPixelBuffer(_ pixelBuffer: CVPixelBuffer, texture: Texture) {
        guard let pixelBufferBytes = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            debugPrint("Could not get buffer bytes")
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let outputTexture: Texture
        if (Int(round(self.videoSize.width)) != texture.texture.width) && (Int(round(self.videoSize.height)) != texture.texture.height) {
            outputTexture = Texture(Int(videoSize.width), Int(videoSize.height), timestamp: texture.timestamp, textureKey: texture.textureKey)

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
            commandEncoder?.setFragmentTexture(texture.texture, index: 0)
            commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            commandEncoder?.endEncoding()
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
        } else {
            outputTexture = texture
        }

        let region = MTLRegionMake2D(0, 0, outputTexture.texture.width, outputTexture.texture.height)
        outputTexture.texture.getBytes(pixelBufferBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
    }
}

// MARK: Audio processing
extension MetalVideoWriter {
    public func newAudioAvailable(_ sampleBuffer: CMSampleBuffer) {
        handleAudio(sampleBuffer)
        audioOperationFinished(sampleBuffer)
    }

    private func handleAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, startTime != nil,
            let audioInput = assetWriterAudioInput else { return }

        if audioInput.isReadyForMoreMediaData {
            audioInput.append(sampleBuffer)
        }
    }
}

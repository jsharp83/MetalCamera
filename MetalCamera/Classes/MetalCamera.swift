import AVFoundation

enum MetalCameraError: Error {
    case noVideoDevice
    case noAudioDevice
    case deviceInputInitialize
}

public class MetalCamera: NSObject, OperationChain, AudioOperationChain {
    public var runBenchmark = false
    public var logFPS = false

    public let captureSession: AVCaptureSession
    public let inputCamera: AVCaptureDevice!

    let videoInput: AVCaptureDeviceInput!
    let videoOutput: AVCaptureVideoDataOutput!
    var videoTextureCache: CVMetalTextureCache?

    var audioInput: AVCaptureDeviceInput?
    var audioOutput: AVCaptureAudioDataOutput?

    let cameraProcessingQueue = DispatchQueue.global()
    let cameraFrameProcessingQueue = DispatchQueue(label: "MetalCamera.cameraFrameProcessingQueue", attributes: [])

    let frameRenderingSemaphore = DispatchSemaphore(value: 1)

    var numberOfFramesCaptured = 0
    var totalFrameTimeDuringCapture: Double = 0.0
    var framesSinceLastCheck = 0
    var lastCheckTime = CFAbsoluteTimeGetCurrent()

    public let sourceKey: String
    public var targets = TargetContainer<OperationChain>()
    public var audioTargets = TargetContainer<AudioOperationChain>()

    let useMic: Bool

    public init(sessionPreset: AVCaptureSession.Preset = .hd1280x720,
                position: AVCaptureDevice.Position = .front,
                sourceKey: String = "camera",
                useMic: Bool = false,
                videoOrientation: AVCaptureVideoOrientation? = nil,
                isVideoMirrored: Bool? = nil) throws {
        guard let device = position.device() else {
            throw MetalCameraError.noVideoDevice
        }

        inputCamera = device
        self.sourceKey = sourceKey

        self.useMic = useMic

        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()

        do {
            self.videoInput = try AVCaptureDeviceInput(device: inputCamera)
        } catch {
            throw MetalCameraError.deviceInputInitialize
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        }

        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferMetalCompatibilityKey as String: true,
                                     kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if useMic {
            guard let audio = AVCaptureDevice.default(for: .audio),
                let audioInput = try? AVCaptureDeviceInput(device: audio) else {
                    throw MetalCameraError.noAudioDevice
            }

            let audioDataOutput = AVCaptureAudioDataOutput()

            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }

            if captureSession.canAddOutput(audioDataOutput) {
                captureSession.addOutput(audioDataOutput)
            }

            self.audioInput = audioInput
            self.audioOutput = audioDataOutput
        }

        captureSession.sessionPreset = sessionPreset
        captureSession.commitConfiguration()

        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, sharedMetalRenderingDevice.device, nil, &videoTextureCache)

        super.init()
        videoOutput.setSampleBufferDelegate(self, queue: cameraProcessingQueue)

        if let orientation = videoOrientation {
            videoOutput.connection(with: .video)?.videoOrientation = orientation
        }

        if let isVideoMirrored = isVideoMirrored {
            videoOutput.connection(with: .video)?.isVideoMirrored = isVideoMirrored
        }

        audioOutput?.setSampleBufferDelegate(self, queue: cameraProcessingQueue)
    }

    deinit {
        cameraFrameProcessingQueue.sync {
            stopCapture()
            videoOutput?.setSampleBufferDelegate(nil, queue:nil)
        }
    }

    public func startCapture() {
        guard captureSession.isRunning == false else { return }

        let _ = frameRenderingSemaphore.wait(timeout:DispatchTime.distantFuture)
        numberOfFramesCaptured = 0
        totalFrameTimeDuringCapture = 0
        frameRenderingSemaphore.signal()

        captureSession.startRunning()
    }

    public func stopCapture() {
        guard captureSession.isRunning else { return }

        let _ = frameRenderingSemaphore.wait(timeout:DispatchTime.distantFuture)
        captureSession.stopRunning()
        self.frameRenderingSemaphore.signal()
    }

    public func newTextureAvailable(_ texture: Texture) {}
    public func newAudioAvailable(_ sampleBuffer: AudioBuffer) {}
}

extension MetalCamera: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if connection == videoOutput?.connection(with: .video) {
            for target in targets {
                if let target = target as? CMSampleChain {
                    target.newBufferAvailable(sampleBuffer)
                }
            }

            handleVideo(sampleBuffer)

        } else if connection == audioOutput?.connection(with: .audio) {
            handleAudio(sampleBuffer)
        }
    }

    private func handleVideo(_ sampleBuffer: CMSampleBuffer) {
        guard (frameRenderingSemaphore.wait(timeout:DispatchTime.now()) == DispatchTimeoutResult.success) else { return }
        guard let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let videoTextureCache = videoTextureCache else { return }

        let startTime = CFAbsoluteTimeGetCurrent()
        let bufferWidth = CVPixelBufferGetWidth(cameraFrame)
        let bufferHeight = CVPixelBufferGetHeight(cameraFrame)
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        CVPixelBufferLockBaseAddress(cameraFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))

        cameraFrameProcessingQueue.async {
            CVPixelBufferUnlockBaseAddress(cameraFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))

            let texture: Texture?

            var textureRef: CVMetalTexture? = nil
            let _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache, cameraFrame, nil, .bgra8Unorm, bufferWidth, bufferHeight, 0, &textureRef)
            if let concreteTexture = textureRef,
                let cameraTexture = CVMetalTextureGetTexture(concreteTexture) {
                texture = Texture(texture: cameraTexture, timestamp: currentTime, textureKey: self.sourceKey)
            } else {
                texture = nil
            }

            if let texture = texture {
                self.operationFinished(texture)
            }

            if self.runBenchmark {
                self.numberOfFramesCaptured += 1

                let currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime)
                self.totalFrameTimeDuringCapture += currentFrameTime
                debugPrint("Average frame time : \(1000.0 * self.totalFrameTimeDuringCapture / Double(self.numberOfFramesCaptured)) ms")
                debugPrint("Current frame time : \(1000.0 * currentFrameTime) ms")
            }

            if self.logFPS {
                if ((CFAbsoluteTimeGetCurrent() - self.lastCheckTime) > 1.0) {
                    self.lastCheckTime = CFAbsoluteTimeGetCurrent()
                    debugPrint("FPS: \(self.framesSinceLastCheck)")
                    self.framesSinceLastCheck = 0
                }
                self.framesSinceLastCheck += 1
            }

            self.frameRenderingSemaphore.signal()
        }
    }

    private func handleAudio(_ sampleBuffer: CMSampleBuffer) {
        audioOperationFinished(AudioBuffer(sampleBuffer, sourceKey))
    }
}


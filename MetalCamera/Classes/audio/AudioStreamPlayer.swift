//
//  AudioStreamPlayer.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/08.
//

import Foundation
import AVFoundation
import AudioToolbox


// FIXME: This class is not fully implemented yet. Don't use this or fixMe :)
class AudioStreamPlayer: NSObject, AudioOperationChain {
    public var audioTargets = TargetContainer<AudioOperationChain>()
//    public var preservedBuffer: AudioBuffer?
//
//    var outputQueue: UnsafeMutablePointer<AudioQueueRef?> = UnsafeMutablePointer<AudioQueueRef?>.allocate(capacity: 1)
//    var streamDescription: AudioStreamBasicDescription?
//
//    let engine = AVAudioEngine()
//    let playerNode = AVAudioPlayerNode()
//    let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)
//
//    let audioQueue = DispatchQueue(label: "MetalCamera.AudioStreamPlayer", attributes: [])
//    let audioSemaphore = DispatchSemaphore(value: 1)
//
//    var isPlaying = false

    public override init() {
//        engine.attach(playerNode)
//        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
//        engine.prepare()
//
//        do {
//            try engine.start()
//        } catch {
//            debugPrint(error)
//        }
    }

//    private func createAudioQueue(audioStreamDescription: AudioStreamBasicDescription) {
//        var audioStreamDescription = audioStreamDescription
//        self.streamDescription = audioStreamDescription
//
//        var status: OSStatus = 0
//        let selfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
//
//        status = AudioQueueNewOutput(&audioStreamDescription, { (pointer, aq, bufferRef) in
//            print("New output")
//        }, selfPointer, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes as! CFString, 0, self.outputQueue)
//
//        assert(noErr == status)
//
//        guard let audioQueueRef = outputQueue.pointee else { return }
//
//        status = AudioQueueAddPropertyListener(audioQueueRef, kAudioQueueProperty_IsRunning, { (pointer, aq, propertyID) in
//            print("Add Listner")
//        }, selfPointer)
//
//        assert(noErr == status)
//
//        AudioQueuePrime(audioQueueRef, 0, nil)
//        AudioQueueStart(audioQueueRef, nil)
//    }

    public func newAudioAvailable(_ sampleBuffer: AudioBuffer) {
        audioOperationFinished(sampleBuffer)
    }

//    func playSampleBuffer(_ sampleBuffer: AudioBuffer) {
//        if engine.isRunning  == false {
//            print("Engine is not runing")
//            engine.prepare()
//
//            do {
//                try engine.start()
//            } catch {
//                debugPrint(error)
//            }
//        }
//
////        guard isPlaying == false else {
////            return
////        }
////
////        isPlaying = true
//
////        guard let data = convert(sampleBuffer) else { return }
//
////        if isPlaying == false {
////            isPlaying = true
//
////            let asbd = createAudioDescription(sampleRate: 44100.0)
////            createAudioQueue(audioStreamDescription: asbd.pointee)
//
//
//
//        guard let desc = CMSampleBufferGetFormatDescription(sampleBuffer.buffer) else {
//            debugPrint("Check SampleBufferFormatDescription")
//            return
//        }
//
//        let numOfSamples = CMSampleBufferGetNumSamples(sampleBuffer.buffer)
//        let audioFormat = AVAudioFormat(cmAudioFormatDescription: desc)
//
//        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numOfSamples)) else {
//            debugPrint("Check convert CMSampleBuffer to AVAudioPCMBuffer")
//            return
//        }
//
//        CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer.buffer, 0, Int32(numOfSamples), pcmBuffer.mutableAudioBufferList)
//
//        playerNode.scheduleBuffer(pcmBuffer, completionCallbackType: .dataConsumed) { (type) in
//            print("here!")
//        }
//
//        if playerNode.isPlaying == false {
//            playerNode.play()
//            print("PlayerNode play")
//        }
//
//
//
//
////        playerNode.scheduleBuffer(pcmBuffer, completionHandler: nil)
////        playerNode.scheduleBuffer(pcmBuffer) {
////            print("here!")
////        }
////
////        self.playerNode.play()
////        self.isPlaying = false
//
//
//
////        playerNode.play()
////        playerNode.scheduleBuffer(pcmBuffer) {
////            print("Play Complete")
////            self.isPlaying = false
////        }
//
////        playPCMBuffer(ㅜㅁ
////        } else {
////            debugPrint("Error: audio is already playing back.")
////        }
//    }

    func playPCMBuffer(_ pcmBuffer: AVAudioPCMBuffer) {

    }

    func scheduleBuffer(_ sampleBuffer: CMSampleBuffer) {

    }

    func convert(_ sampleBuffer: AudioBuffer) -> Data? {
        let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer.buffer)
        let blockBufferDataLength = CMBlockBufferGetDataLength(blockBuffer!)

        var blockBufferData  = [UInt8](repeating: 0, count: blockBufferDataLength)
        let status = CMBlockBufferCopyDataBytes(blockBuffer!, 0, blockBufferDataLength, &blockBufferData)
        guard status == noErr else { return nil }
        let data = Data(bytes: blockBufferData, count: blockBufferDataLength)
        return data
    }

    func createAudioDescription(sampleRate: Float64) -> UnsafeMutablePointer<AudioStreamBasicDescription> {
        let descRef = UnsafeMutablePointer<AudioStreamBasicDescription>.allocate(capacity: 1)

        descRef.pointee.mSampleRate = sampleRate
        descRef.pointee.mFormatID = kAudioFormatLinearPCM
        descRef.pointee.mFormatFlags = (kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kLinearPCMFormatFlagIsPacked)
        descRef.pointee.mBitsPerChannel = 32
        descRef.pointee.mChannelsPerFrame = 1
        descRef.pointee.mBytesPerFrame = descRef.pointee.mChannelsPerFrame * descRef.pointee.mBitsPerChannel >> 3
        descRef.pointee.mFramesPerPacket = 1
        descRef.pointee.mBytesPerPacket = descRef.pointee.mFramesPerPacket * descRef.pointee.mBytesPerFrame
        descRef.pointee.mReserved = 0

        return descRef
    }

    //    func playTestAudio() {
    //        var audioDesc = AudioComponentDescription()
    //        audioDesc.componentType = kAudioUnitType_Output
    //        audioDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO
    //        audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple
    //        audioDesc.componentFlags = 0
    //        audioDesc.componentFlagsMask = 0
    //
    //        guard let inputComponent = AudioComponentFindNext(nil, &audioDesc) else {
    //            debugPrint("AudioInputComponent is not found. Check AudioComponentDescription")
    //            return
    //        }
    //        AudioComponentInstanceNew(inputComponent, &audioUnit)
    //
    //        let bufferListRef = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
    //        bufferListRef.pointee.mNumberBuffers = 1
    //
    //        let kOutputBus: UInt32 = 0
    //        let kInputBus: UInt32 = 1
    //        var flag = 1
    //
    //        var status = AudioUnitSetProperty(audioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, UInt32( MemoryLayout<UInt32>.size))
    //
    //        print(status)
    //
    //        status = AudioUnitSetProperty(audioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &flag, UInt32( MemoryLayout<UInt32>.size))
    //
    //        print(status)
    //
    //        let channel = 1
    //
    //        var format = AudioStreamBasicDescription(
    //            mSampleRate : Double(44100),
    //            mFormatID : kAudioFormatLinearPCM,
    //            mFormatFlags : kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
    //            mBytesPerPacket : UInt32( channel * 2 ),   // 16bit
    //            mFramesPerPacket : 1,
    //            mBytesPerFrame : UInt32( channel * 2),
    //            mChannelsPerFrame : UInt32( channel ),
    //            mBitsPerChannel : UInt32( 8 * 2),
    //            mReserved: UInt32(0))
    //
    //        status = AudioUnitSetProperty(audioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &format, UInt32( MemoryLayout<AudioStreamBasicDescription>.size))
    //
    //        print(status)
    //
    //        status = AudioUnitSetProperty(audioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &format, UInt32( MemoryLayout<AudioStreamBasicDescription>.size))
    //
    //        print(status)
    //
    //        var inputCallback = AURenderCallbackStruct()
    //        inputCallback.inputProc = { (inRefCon, flags, timestamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
    //            return 0
    //        }
    //        inputCallback.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
    //
    //        status = AudioUnitSetProperty(audioUnit!, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBus, &inputCallback, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
    //
    //        print(status)
    //
    //        var renderCallback = AURenderCallbackStruct()
    //        renderCallback.inputProc = { (inRefCon, flags, timestamp, inBusNumber, inNumberFrames, ioData) -> OSStatus in
    //            print("Output Calback!!!")
    //            var status = AudioUnitRender(audioUnit!, flags, timestamp, inBusNumber, inNumberFrames, ioData!)
    //            print(status)
    //            return status
    //        }
    //        renderCallback.inputProcRefCon = Unmanaged.passUnretained(self).toOpaque()
    //
    //        status = AudioUnitSetProperty(audioUnit!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &renderCallback, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
    //
    //        print(status)
    //
    //        status = AudioUnitInitialize(audioUnit!)
    //        print(status)
    //
    //        AudioOutputUnitStart(audioUnit!)
    //    }

//    func setupAudio() {
//        // 1
//        let bundleURL = Bundle.main.resourceURL!
//        let movieURL = URL(string: "bunny.mp4", relativeTo: bundleURL)!
//
//        audioFileURL = movieURL
//
//        // 2
//        engine.attach(player)
//        engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
//        engine.prepare()
//
//        do {
//            // 3
//            try engine.start()
//        } catch let error {
//            print(error.localizedDescription)
//        }
//
//        guard let audioFile = audioFile else { return }
//
//        //        skipFrame = 0
//        player.scheduleFile(audioFile, at: nil) { [weak self] in
//            //          self?.needsFileScheduled = true
//
//        }
//
//        self.player.play()
//
//    }
}

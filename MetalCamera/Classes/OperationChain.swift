//
//  OperationChain.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/04.
//

import Foundation
import AVFoundation

public protocol OperationChain: AnyObject {
    var targets: TargetContainer<OperationChain> { get }
    func newTextureAvailable(_ texture: Texture)
    func operationFinished(_ texture: Texture)
}

extension OperationChain {
    func addTarget(_ target: OperationChain) {
        targets.append(target)
    }

    public func removeTarget(_ target: OperationChain) {
        targets.remove(target)
    }

    func removeAllTargets() {
        targets.removeAll()
    }

    public func operationFinished(_ texture: Texture) {
        for target in targets {
            target?.newTextureAvailable(texture)
        }
    }
}

public protocol CMSampleChain: OperationChain {
    func newBufferAvailable(_ sampleBuffer: CMSampleBuffer)
}

public protocol AudioOperationChain: AnyObject {
    var audioTargets: TargetContainer<AudioOperationChain> { get }
    func newAudioAvailable(_ sampleBuffer: AudioBuffer)
    func audioOperationFinished(_ sampleBuffer: AudioBuffer)
}

extension AudioOperationChain {
    func addAudioTarget(_ target: AudioOperationChain) {
        audioTargets.append(target)
    }

    public func removeAudioTarget(_ target: AudioOperationChain) {
        audioTargets.remove(target)
    }

    func removeAllAudioTargets() {
        audioTargets.removeAll()
    }

    public func audioOperationFinished(_ sampleBuffer: AudioBuffer) {
        for target in audioTargets {
            target?.newAudioAvailable(sampleBuffer)
        }
    }
}


infix operator --> : AdditionPrecedence
infix operator ==> : AdditionPrecedence
//precedencegroup ProcessingOperationPrecedence {
//    associativity: left
////    higherThan: Multiplicative
//}
@discardableResult public func --><T: OperationChain>(source: OperationChain, destination: T) -> T {
    source.addTarget(destination)
    return destination
}

@discardableResult public func ==><T: AudioOperationChain>(source: AudioOperationChain, destination: T) -> T {
    source.addAudioTarget(destination)
    return destination
}

public class TargetContainer<T>: Sequence {
    var targets = [T]()
    var count: Int { get { return targets.count }}
    let dispatchQueue = DispatchQueue(label:"MetalCamera.targetContainerQueue", attributes: [])

    public init() {
    }

    public func append(_ target: T) {
        dispatchQueue.async{
            self.targets.append(target)
        }
    }

    public func remove(_ target: T) {
        dispatchQueue.async {
            self.targets.removeAll {
                $0 as AnyObject === target as AnyObject
            }
        }
    }

    public func makeIterator() -> AnyIterator<T?> {
        var index = 0

        return AnyIterator { () -> T? in
            return self.dispatchQueue.sync{
                if (index >= self.targets.count) {
                    return nil
                }

                index += 1
                return self.targets[index - 1]
            }
        }
    }

    public func removeAll() {
        dispatchQueue.async{
            self.targets.removeAll()
        }
    }
}

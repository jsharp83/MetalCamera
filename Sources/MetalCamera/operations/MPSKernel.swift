//
//  MPSKernel.swift
//  MetalCamera
//
//  Created by Eric on 2020/07/21.
//

import Foundation
import MetalPerformanceShaders

public class Kernel: OperationChain {
    public let targets = TargetContainer<OperationChain>()
    private let textureInputSemaphore = DispatchSemaphore(value:1)
    private let kernel: MPSUnaryImageKernel

    public init(_ kernel: MPSUnaryImageKernel) {
        self.kernel = kernel
    }

    public func newTextureAvailable(_ texture: Texture) {
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }

        let outputTexture = Texture(Int(texture.texture.width), Int(texture.texture.height), timestamp: texture.timestamp, textureKey: texture.textureKey)

        if let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() {
            kernel.encode(commandBuffer: commandBuffer, sourceTexture: texture.texture, destinationTexture: outputTexture.texture)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        textureInputSemaphore.signal()
        operationFinished(outputTexture)
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
    }
}


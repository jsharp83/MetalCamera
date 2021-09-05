//
//  AlphaBlend.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/16.
//

import UIKit

public let standardImageVertices: [Float] = [-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0]
public let standardTextureCoordinate: [Float] = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]

public class AlphaBlend: TwoTextureOperationChain {
    public var targets = TargetContainer<OperationChain>()

    private var pipelineState: MTLRenderPipelineState!
    private let textureInputSemaphore = DispatchSemaphore(value:1)

    private var textureBuffer1: MTLBuffer?
    private var textureBuffer2: MTLBuffer?

    public var alphaValue: Float = 0.5

    public init() {
        setup()
    }

    private func setup() {
        setupPiplineState()
    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("two_vertex_render_target", "alphaBlendFragment", colorPixelFormat)
            pipelineState = try sharedMetalRenderingDevice.device.makeRenderPipelineState(descriptor: rpd)
        } catch {
            debugPrint(error)
        }
    }

    private func generateTextureBuffer(_ width: Int, _ height: Int, _ targetWidth: Int, _ targetHeight: Int) -> MTLBuffer? {
        let targetRatio = Float(targetWidth)/Float(targetHeight)
        let curRatio = Float(width)/Float(height)

        let coordinates: [Float]

        if targetRatio > curRatio {
            let remainHeight = (Float(height) - Float(width) * targetRatio)/2.0
            let remainRatio = remainHeight/Float(height)
            coordinates = [0.0, remainRatio, 1.0, remainRatio, 0.0, 1.0 - remainRatio, 1.0, 1.0 - remainRatio]
        } else {
            let remainWidth = (Float(width) - Float(height) * targetRatio)/2.0
            let remainRatio = remainWidth/Float(width)
            coordinates = [remainRatio, 0.0, 1.0 - remainRatio, 0.0, remainRatio, 1.0, 1.0 - remainRatio, 1.0]
        }

        let textureBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: coordinates,
                                                                         length: coordinates.count * MemoryLayout<Float>.size,
                                                                         options: [])!
        return textureBuffer
    }

    public func newTextureAvailable(_ source1: Texture, _ source2: Texture, completion: @escaping ((_ texture: Texture) -> Void)) {
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }

        let minX = min(source1.texture.width, source2.texture.width)
        let minY = min(source1.texture.height, source2.texture.height)

        if textureBuffer1 == nil {
            textureBuffer1 = generateTextureBuffer(source1.texture.width, source1.texture.height, minX, minY)
        }
        if textureBuffer2 == nil {
            textureBuffer2 = generateTextureBuffer(source2.texture.width, source2.texture.height, minX, minY)
        }

        let outputTexture = Texture(minX, minY, timestamp: source1.timestamp, textureKey: source1.textureKey)

        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.clearColor = MTLClearColorMake(1, 0, 0, 1)
        attachment?.texture = outputTexture.texture
        attachment?.loadAction = .clear
        attachment?.storeAction = .store

        let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        commandEncoder?.setFrontFacing(.counterClockwise)
        commandEncoder?.setRenderPipelineState(pipelineState)

        let vertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: standardImageVertices,
                                                                        length: standardImageVertices.count * MemoryLayout<Float>.size,
                                                                        options: [])!
        vertexBuffer.label = "Vertices"
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(textureBuffer1, offset: 0, index: 1)
        commandEncoder?.setVertexBuffer(textureBuffer2, offset: 0, index: 2)

        commandEncoder?.setFragmentTexture(source1.texture, index: 0)
        commandEncoder?.setFragmentTexture(source2.texture, index: 1)
        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: [alphaValue],
                                                                         length: 1 * MemoryLayout<Float>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)

        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()

        textureInputSemaphore.signal()
        completion(outputTexture)
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
    }

    public func newTextureAvailable(_ texture: Texture) {
        fatalError("Should be use newTextureAvailable(_ base: Texture, overlay: Texture, completion: @escaping (() -> Void)) func")
    }
}

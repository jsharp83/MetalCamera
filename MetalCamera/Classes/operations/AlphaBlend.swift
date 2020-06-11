//
//  AlphaBlend.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/16.
//

import Foundation

public let standardImageVertices: [Float] = [-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0]
public let standardTextureCoordinate: [Float] = [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0]

//[0.0, 0.0, xLimit, 0.0, 0.0, yLimit, xLimit, yLimit]

public class AlphaBlend: OperationChain {
    public var targets = TargetContainer<OperationChain>()

    private var pipelineState: MTLRenderPipelineState!
    private let textureInputSemaphore = DispatchSemaphore(value:1)
    private let uniformValues: [Float] = [0.5]

    private var textureBuffer1: MTLBuffer?
    private var textureBuffer2: MTLBuffer?

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

        // [0.0, 0.0, xLimit, 0.0, 0.0, yLimit, xLimit, yLimit]
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

    public func newTextureAvailable(_ base: Texture, overlay: Texture, completion: @escaping ((_ texture: Texture) -> Void)) {
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }

        let minX = min(base.texture.width, overlay.texture.width)
        let minY = min(base.texture.height, overlay.texture.height)

        if textureBuffer1 == nil {
            textureBuffer1 = generateTextureBuffer(base.texture.width, base.texture.height, minX, minY)
        }
        if textureBuffer2 == nil {
            textureBuffer2 = generateTextureBuffer(overlay.texture.width, overlay.texture.height, minX, minY)
        }

        let outputTexture = Texture(minX, minY, timestamp: base.timestamp, textureKey: base.textureKey)

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

        commandEncoder?.setFragmentTexture(base.texture, index: 0)
        commandEncoder?.setFragmentTexture(overlay.texture, index: 1)
        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: uniformValues,
                                                                         length: uniformValues.count * MemoryLayout<Float>.size,
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

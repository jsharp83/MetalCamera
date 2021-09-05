//
//  Rotation.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import UIKit

public class Gray: OperationChain {
    public let targets = TargetContainer<OperationChain>()

    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    private let textureInputSemaphore = DispatchSemaphore(value:1)

    public init() {
        setup()
    }

    private func setup() {
        setupPiplineState()
    }

    private func loadRenderTargetVertex(_ baseTextureSize: CGSize) {
        render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(size: baseTextureSize)
        render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(baseTextureSize)
    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "gray_fragment_render_target", colorPixelFormat)
            pipelineState = try sharedMetalRenderingDevice.device.makeRenderPipelineState(descriptor: rpd)
        } catch {
            debugPrint(error)
        }
    }

    public func newTextureAvailable(_ texture: Texture) {
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }

        if render_target_vertex == nil {
            let baseTextureSize = CGSize(width: texture.texture.width, height: texture.texture.height)
            loadRenderTargetVertex(baseTextureSize)
        }

        let outputTexture = Texture(Int(texture.texture.width), Int(texture.texture.height), timestamp: texture.timestamp, textureKey: texture.textureKey)

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

        textureInputSemaphore.signal()
        operationFinished(outputTexture)
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
    }
}


//
//  Compositor.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import Foundation
import MetalKit

public class ImageCompositor: OperationChain {
    public let targets = TargetContainer<OperationChain>()

    public var sourceTextureKey: String = ""
    public var sourceFrame: CGRect?

    private let baseTextureKey: String
    private var sourceTexture: MTLTexture?

    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    private let textureInputSemaphore = DispatchSemaphore(value:1)

    public init(baseTextureKey: String) {
        self.baseTextureKey = baseTextureKey
        setup()
    }

    private func setup() {
        setupPiplineState()
    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "fragment_render_target", colorPixelFormat)
            pipelineState = try sharedMetalRenderingDevice.device.makeRenderPipelineState(descriptor: rpd)
        } catch {
            debugPrint(error)
        }
    }

    public func addCompositeImage(_ image: UIImage) {
        sourceTexture = image.loadTexture(device: sharedMetalRenderingDevice.device)
    }

    public func newTextureAvailable(_ texture: Texture) {
        if texture.textureKey == self.baseTextureKey {
            baseTextureAvailable(texture)
        } else if texture.textureKey == self.sourceTextureKey {
            sourceTexture = texture.texture
        }
    }

    private func loadRenderTargetVertex(_ baseTextureSize: CGSize) {
        guard let sourceFrame = sourceFrame else { return }
        render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(sourceFrame.origin, size: sourceFrame.size)
        render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(baseTextureSize)
    }

    private func baseTextureAvailable(_ texture: Texture) {
        guard let soruceTexture = sourceTexture else {
            // Bypass received texture if there is no source texture.
            operationFinished(texture)
            return
        }

        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }

        if render_target_vertex == nil {
            let baseTextureSize = CGSize(width: texture.texture.width, height: texture.texture.height)
            loadRenderTargetVertex(baseTextureSize)
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        let attachment = renderPassDescriptor.colorAttachments[0]
        attachment?.texture = texture.texture
        attachment?.loadAction = .load
        attachment?.storeAction = .store

        let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        commandEncoder?.setRenderPipelineState(pipelineState)

        commandEncoder?.setVertexBuffer(render_target_vertex, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(render_target_uniform, offset: 0, index: 1)
        commandEncoder?.setFragmentTexture(soruceTexture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        commandEncoder?.endEncoding()
        commandBuffer?.commit()

        textureInputSemaphore.signal()
        operationFinished(texture)
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        
    }
}

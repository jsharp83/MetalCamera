//
//  Lookup.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/21.
//

import Foundation
import MetalKit

public class Lookup: OperationChain {
    public let targets = TargetContainer<OperationChain>()

    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!
    private let textureInputSemaphore = DispatchSemaphore(value:1)

    private var lookupTexture: MTLTexture?
    private var textureCoordinate: MTLBuffer?

    public var intensity: Float = 0.5

    public init(_ lookupImage: CGImage) {
        setup()
        loadLookupTexture(lookupImage)
    }

    private func setup() {
        setupPiplineState()

        textureCoordinate = sharedMetalRenderingDevice.device.makeBuffer(bytes: standardTextureCoordinate,
                                                                         length: standardTextureCoordinate.count * MemoryLayout<Float>.size,
                                                                         options: [])!
    }

    private func loadLookupTexture(_ lookupImage: CGImage) {
        let loader = MTKTextureLoader(device: sharedMetalRenderingDevice.device)
        loader.newTexture(cgImage: lookupImage, options: [MTKTextureLoader.Option.SRGB: false]) { (texture, error) in
            if let error = error {
                debugPrint(error)
            } else {
                self.lookupTexture = texture
            }
        }
    }

    private func loadRenderTargetVertex(_ baseTextureSize: CGSize) {
        render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(size: baseTextureSize)
        render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(baseTextureSize)
    }

    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("two_vertex_render_target", "lookupFragment", colorPixelFormat)
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

        let vertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: standardImageVertices,
                                                                        length: standardImageVertices.count * MemoryLayout<Float>.size,
                                                                        options: [])!
        vertexBuffer.label = "Vertices"
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(textureCoordinate, offset: 0, index: 1)
        commandEncoder?.setVertexBuffer(textureCoordinate, offset: 0, index: 2)

        commandEncoder?.setFragmentTexture(texture.texture, index: 0)
        commandEncoder?.setFragmentTexture(lookupTexture, index: 1)


        let uniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: [intensity],
                                                                         length: 1 * MemoryLayout<Float>.size,
                                                                         options: [])!
        commandEncoder?.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)

        commandEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        commandEncoder?.endEncoding()
        commandBuffer?.commit()

        textureInputSemaphore.signal()
        operationFinished(outputTexture)
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
    }
}

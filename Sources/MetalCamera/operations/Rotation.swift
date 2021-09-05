//
//  Rotation.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import UIKit

public enum Rotation {
    case degree90
    case degree90_flip
    case degree180
    case degree270

    func generateVertices(_ size: CGSize) -> [Vertex] {
        let vertices: [Vertex]
        let w = size.width
        let h = size.height

        switch self {
        case .degree90: 
            vertices = [
                Vertex(position: CGPoint(x: 0 , y: 0), textCoord: CGPoint(x: 0, y: 1)),
                Vertex(position: CGPoint(x: w , y: 0), textCoord: CGPoint(x: 0, y: 0)),
                Vertex(position: CGPoint(x: 0 , y: h), textCoord: CGPoint(x: 1, y: 1)),
                Vertex(position: CGPoint(x: w , y: h), textCoord: CGPoint(x: 1, y: 0)),
            ]
        case .degree90_flip:
            vertices = [
                Vertex(position: CGPoint(x: 0 , y: 0), textCoord: CGPoint(x: 0, y: 0)),
                Vertex(position: CGPoint(x: w , y: 0), textCoord: CGPoint(x: 0, y: 1)),
                Vertex(position: CGPoint(x: 0 , y: h), textCoord: CGPoint(x: 1, y: 0)),
                Vertex(position: CGPoint(x: w , y: h), textCoord: CGPoint(x: 1, y: 1)),
            ]
        case .degree180:
            vertices = [
                Vertex(position: CGPoint(x: 0 , y: 0), textCoord: CGPoint(x: 1, y: 1)),
                Vertex(position: CGPoint(x: w , y: 0), textCoord: CGPoint(x: 0, y: 1)),
                Vertex(position: CGPoint(x: 0 , y: h), textCoord: CGPoint(x: 1, y: 0)),
                Vertex(position: CGPoint(x: w , y: h), textCoord: CGPoint(x: 0, y: 0)),
            ]
        case .degree270:
            vertices = [
                Vertex(position: CGPoint(x: 0 , y: 0), textCoord: CGPoint(x: 1, y: 0)),
                Vertex(position: CGPoint(x: w , y: 0), textCoord: CGPoint(x: 1, y: 1)),
                Vertex(position: CGPoint(x: 0 , y: h), textCoord: CGPoint(x: 0, y: 0)),
                Vertex(position: CGPoint(x: w , y: h), textCoord: CGPoint(x: 0, y: 1)),
            ]
        }

        return vertices
    }
}

public class RotationOperation: OperationChain {
    public let targets = TargetContainer<OperationChain>()

    private let rotation: Rotation
    private let size: CGSize

    private var pipelineState: MTLRenderPipelineState!
    private var render_target_vertex: MTLBuffer!
    private var render_target_uniform: MTLBuffer!

    private let textureInputSemaphore = DispatchSemaphore(value:1)

    public init(_ rotation: Rotation, _ size: CGSize = CGSize(width: 720, height: 1280)) {
        self.rotation = rotation
        self.size = size
        setup()
    }

    private func setup() {
        setupTargetUniforms()
        setupPiplineState()
    }

    private func setupTargetUniforms() {
        render_target_vertex = sharedMetalRenderingDevice.makeRenderVertexBuffer(rotation.generateVertices(size))
        render_target_uniform = sharedMetalRenderingDevice.makeRenderUniformBuffer(size)
    }

    // FIXME: Need to refactoring this. There are a lot of same functions in library.
    private func setupPiplineState(_ colorPixelFormat: MTLPixelFormat = .bgra8Unorm) {
        do {
            let rpd = try sharedMetalRenderingDevice.generateRenderPipelineDescriptor("vertex_render_target", "fragment_render_target", colorPixelFormat)
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

        let outputTexture = Texture(Int(size.width), Int(size.height), timestamp: texture.timestamp, textureKey: texture.textureKey)

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


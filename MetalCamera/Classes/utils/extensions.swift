//
//  extensions.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/06.
//

import Foundation
import AVFoundation
import MetalKit

extension AVCaptureDevice.Position {
    func device() -> AVCaptureDevice? {
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                           mediaType: .video,
                                                                           position: self)

        for device in deviceDescoverySession.devices where device.position == self {
            return device
        }

        return nil
    }
}

extension UIImage {
    func loadTexture(device: MTLDevice) -> MTLTexture {
        guard let cgImage = self.cgImage else {
            fatalError("Couldn't load CGImage")
        }

        do {
            let textureLoader = MTKTextureLoader(device: device)
            return try textureLoader.newTexture(cgImage: cgImage, options: [MTKTextureLoader.Option.SRGB: false])
        } catch {
            fatalError("Couldn't convert CGImage to MTLTexture")
        }
    }
}

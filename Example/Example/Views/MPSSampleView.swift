//
//  MPSSampleView.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/07.
//

import MetalCamera
import MetalPerformanceShaders
import SwiftUI

struct MPSSampleView: View {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    let sobel = MPSImageSobel(device: sharedMetalRenderingDevice.device)
    let kernel: Kernel?
    
    init() {
        let kernel = Kernel(sobel)
        camera-->kernel
        self.kernel = kernel
    }
    
    var body: some View {
        if let kernel = kernel {
            VideoPreview(operation: kernel)
                .onAppear {
                    camera.startCapture()
                }
                .onDisappear {
                    camera.stopCapture()
                }
        } else {
            Text("Preparing...")
        }
    }
}

struct MPSSampleView_Previews: PreviewProvider {
    static var previews: some View {
        MPSSampleView()
    }
}

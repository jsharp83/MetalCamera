//
//  VisionSegmentationView.swift
//  Example
//
//  Created by  Eric on 2022/02/04.
//

import MetalCamera
import SwiftUI

struct VisionSegmentationView: View {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    let segmentationHandler = PersonSegmentationHandler()
    
    var body: some View {
        ZStack {
            VideoPreview(operation: segmentationHandler)
                .onAppear {
                    setup()
                    camera.startCapture()
                }
                .onDisappear {
                    camera.stopCapture()
                }
        }
    }
}

extension VisionSegmentationView {
    private func setup() {
        camera-->segmentationHandler
    }
}

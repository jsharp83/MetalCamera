//
//  VisionSegmentationView.swift
//  Example
//
//  Created by  Eric on 2022/02/04.
//

import MetalCamera
import SwiftUI

struct VisionSegmentationView: View {
    @ObservedObject var viewModel = VisionSegmentationViewModel()
    
    var body: some View {
        if let operation = viewModel.operationChain {
            ZStack {
                VideoPreview(operation: operation)
                    .onAppear {
                        viewModel.camera.startCapture()
                    }
                    .onDisappear {
                        viewModel.camera.stopCapture()
                    }
            }
        } else {
            Text("Preparing...")
        }
    }
}

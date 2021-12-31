//
//  StabilityCheckView.swift
//  Example
//
//  Created by  Eric on 2021/12/31.
//
import MetalCamera
import SwiftUI

struct StabilityCheckView: View {
    @ObservedObject var viewModel = StabilityCheckViewModel()
    
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
                
                if viewModel.stability == .unstable {
                    Color.red.opacity(0.3)
                    
                    Text("Unstable")
                        .foregroundColor(.white)
                }

                VStack(alignment: .trailing) {
                    Text("x: \(viewModel.translationPoint.x), y: \(viewModel.translationPoint.y)")
                        .foregroundColor(.white)
                    Spacer()
                }
            }
        } else {
            Text("Preparing...")
        }
    }
}

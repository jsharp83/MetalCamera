//
//  LookupFilterView.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/07.
//

import MetalCamera
import SwiftUI

struct LookupFilterView: View {
    @ObservedObject var viewModel = LookupFilterViewModel()
    
    var body: some View {
        if let operation = viewModel.operationChain {
            VideoPreview(operation: operation)
                .onAppear {
                    viewModel.camera.startCapture()
                }
                .onDisappear {
                    viewModel.camera.stopCapture()
                }
                .gesture(DragGesture(minimumDistance: 20, coordinateSpace: .global)
                            .onEnded({ _ in
                                viewModel.changeFilter()
                            })
                )
        } else {
            Text("Preparing...")
        }
    }
}

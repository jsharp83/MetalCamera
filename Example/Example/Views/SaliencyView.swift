//
//  SaliencyView.swift
//  Example
//
//  Created by  Eric on 2022/02/06.
//

import MetalCamera
import SwiftUI

struct SaliencyView: View {
    let camera = try! MetalCamera(position: .back ,videoOrientation: .portrait, isVideoMirrored: false)
    let saliencyHandler = SaliencyHandler()
    @State var isObjectBased: Bool = false
    
    var body: some View {
        ZStack {
            VideoPreview(operation: saliencyHandler)
                .onAppear {
                    setup()
                    camera.startCapture()
                }
                .onDisappear {
                    camera.stopCapture()
                }
            
            VStack {
                Toggle(isObjectBased ? "Object" : "Attention", isOn: $isObjectBased)
                    .foregroundColor(.white)
                    .onChange(of: isObjectBased) { value in
                        saliencyHandler.changeType(value ? .objectnessBased : .attentionBased)
                    }
                Spacer()
            }
        }
    }
}

extension SaliencyView {
    private func setup() {
        camera-->saliencyHandler
    }
}

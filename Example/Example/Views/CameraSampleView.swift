//
//  CameraSampleView.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/07.
//

import SwiftUI
import MetalCamera

struct CameraSampleView: View {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    var body: some View {
        VideoPreview(operation: camera)
            .onAppear {
                camera.startCapture()
            }
            .onDisappear {
                camera.stopCapture()
            }
    }
}

struct CameraSampleView_Previews: PreviewProvider {
    static var previews: some View {
        CameraSampleView()
    }
}

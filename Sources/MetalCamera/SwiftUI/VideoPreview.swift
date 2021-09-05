//
//  VideoPreview.swift
//  MetalCamera
//
//  Created by Eunchul Jeon on 2021/09/05.
//

import SwiftUI

public struct VideoPreview: UIViewRepresentable {
    let prevChain: OperationChain
    public init(operation: OperationChain) {
        prevChain = operation
    }
    
    public func makeUIView(context: Context) -> MetalVideoView {
        let view = MetalVideoView()
        prevChain.addTarget(view)
        return view
    }
    
    public func updateUIView(_ uiView: MetalVideoView, context: Context) {
        prevChain.addTarget(uiView)        
    }
}

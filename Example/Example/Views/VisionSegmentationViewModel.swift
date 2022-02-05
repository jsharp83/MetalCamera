//
//  VisionSegmentationViewModel.swift
//  Example
//
//  Created by  Eric on 2022/02/04.
//

import MetalCamera
import UIKit

class VisionSegmentationViewModel: ObservableObject {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    let segmentationHandler = PersonSegmentationHandler()
    
    @Published var operationChain: OperationChain?
    
    init() {
        camera-->segmentationHandler
        operationChain = segmentationHandler
    }
}

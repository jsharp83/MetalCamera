//
//  SegmentationSampleView.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/07.
//

import CoreML
import MetalCamera
import SwiftUI
import Vision

struct SegmentationSampleView: View {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    @State var operationChain: OperationChain?

    let modelURL = URL(string: "https://ml-assets.apple.com/coreml/models/Image/ImageSegmentation/DeepLabV3/DeepLabV3Int8LUT.mlmodel")!
    
    var body: some View {
        if let operationChain = operationChain {
            VideoPreview(operation: operationChain)
                .onAppear {
                    camera.startCapture()
                }
                .onDisappear {
                    camera.stopCapture()
                }
        } else {
            Text("Preparing...")
                .onAppear() {
                    loadCoreML()
                }
        }
    }
}

extension SegmentationSampleView {
    func loadCoreML() {
        do {
            let loader = try CoreMLLoader(url: modelURL)
            loader.load { (model, error) in
                if let model = model {
                    setupModelHandler(model)
                } else if let error = error {
                    debugPrint(error)
                }
            }
        } catch {
            debugPrint(error)
        }
    }

    func setupModelHandler(_ model: MLModel) {
        do {
            let modelHandler = try CoreMLClassifierHandler(model)
            camera.removeAllTargets()
            camera-->modelHandler
            operationChain = modelHandler
        } catch{
            debugPrint(error)
        }
    }
}

//
//  PoseNetSampleViewController.swift
//  MetalCamera_Example
//
//  Created by Eric on 2020/06/29.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import MetalCamera
import CoreML
import Vision

class PoseNetSampleViewController: BaseCameraViewController {
    let modelURL = URL(string: "https://ml-assets.apple.com/coreml/models/Image/PoseEstimation/PoseNet/PoseNetMobileNet075S8FP16.mlmodel")!

    override func viewDidLoad() {
        super.viewDidLoad()
        loadCoreML()
    }
}

extension PoseNetSampleViewController {
    func loadCoreML() {
        do {
            let loader = try CoreMLLoader(url: modelURL)
            loader.load { [weak self](model, error) in
                if let model = model {
                    self?.setupModelHandler(model)
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
            let modelHandler = try CoreMLPoseNetHandler(model)
            camera.removeTarget(preview)
            camera-->modelHandler-->preview
        } catch{
            debugPrint(error)
        }
    }
}

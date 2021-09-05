//
//  MPSSampleViewController.swift
//  MetalCamera_Example
//
//  Created by Eric on 2020/07/21.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import MetalCamera
import MetalPerformanceShaders

class MPSSampleViewController: BaseCameraViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        camera.removeAllTargets()

        let sobel = MPSImageSobel(device: sharedMetalRenderingDevice.device)
        let kernel = MetalKernel(sobel)
        camera-->kernel-->preview
    }
}

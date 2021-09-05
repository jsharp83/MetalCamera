//
//  BaseCameraViewController.swift
//  MetalCamera_Example
//
//  Created by Eric on 2020/06/21.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import MetalCamera

class BaseCameraViewController: UIViewController {
    @IBOutlet weak var preview: MetalVideoView!
    var camera: MetalCamera!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        camera?.startCapture()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        camera?.stopCapture()
    }
}

extension BaseCameraViewController {
    func setupCamera() {
        guard let camera = try? MetalCamera(videoOrientation: .portrait, isVideoMirrored: true) else { return }
        self.camera = camera
        camera-->preview
    }
}

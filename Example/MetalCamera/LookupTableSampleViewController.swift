//
//  LookupTableSampleViewController.swift
//  MetalCamera_Example
//
//  Created by Eric on 2020/06/21.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import MetalCamera

enum LookupFilter: CaseIterable {
    case none
    case amatorka
    case miss_etikate

    var imageFileName: String {
        switch self {
        case .amatorka:
            return "lookup_amatorka.png"
        case .miss_etikate:
            return "lookup_miss_etikate.png"
        case .none:
            return ""
        }
    }

    var cgImage: CGImage? {
        if imageFileName.count > 0 {
            return UIImage(named: imageFileName)?.cgImage
        } else {
            return nil
        }
    }
}

class LookupTableSampleViewController: BaseCameraViewController {
    var lookupFilters = [Lookup?]()
    var selectedIdx = 0
    var prevFilter: Lookup?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupFilters()
        setupGesture()
    }

    func setupFilters() {
        lookupFilters = LookupFilter.allCases
            .map { $0.cgImage }
            .map { $0 != nil ? Lookup($0!) : nil }

        if let filter = lookupFilters[1] {
            updateFilter(filter, 1)
        }
    }

    func setupGesture() {
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(didSwipe))
        swipeGesture.direction = .left
        preview.addGestureRecognizer(swipeGesture)
    }

    @objc func didSwipe() {
        let nextIdx = selectedIdx + 1 > lookupFilters.count - 1 ? 0 : selectedIdx + 1
        updateFilter(lookupFilters[nextIdx], nextIdx)
    }

    func updateFilter(_ filter: Lookup?, _ index: Int) {
        camera.removeAllTargets()
        prevFilter?.removeAllTargets()

        if let filter = filter {
            camera-->filter-->preview
        } else {
            camera-->preview
        }

        prevFilter = filter
        selectedIdx = index
    }
}

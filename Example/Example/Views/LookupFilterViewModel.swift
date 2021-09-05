//
//  LookupFilterViewModel.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/07.
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

class LookupFilterViewModel: ObservableObject {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    let lookupFilters = LookupFilter.allCases
        .compactMap { $0.cgImage }
        .compactMap { Lookup($0) }
    
    @Published var operationChain: OperationChain?
    var currentIndex = 0
    
    init() {
        camera-->lookupFilters.first!
        operationChain = lookupFilters.first
    }
    
    func changeFilter() {
        camera.removeAllTargets()
        operationChain?.removeAllTargets()
        currentIndex = currentIndex + 1 <= lookupFilters.count ? currentIndex + 1 : 0
        if currentIndex < lookupFilters.count {
            camera-->lookupFilters[currentIndex]
            operationChain = lookupFilters[currentIndex]
        } else {
            operationChain = camera
        }
    }
}

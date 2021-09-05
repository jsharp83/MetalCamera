//
//  ExampleViewModel.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/05.
//

import Foundation
import MetalCamera
import SwiftUI

enum Examples: Int, CaseIterable, Identifiable {
    case camera
    case recording
    case segmentation
    case lookup
    case MPS
    
    var id: String {
        return "\(self.rawValue)"
    }
    
    var name: String {
        switch self {
        case .camera:
            return "Camera"
        case .recording:
            return "Composition and Recording"
        case .segmentation:
            return "Segmentation"
        case .lookup:
            return "Lookup Table"
        case .MPS:
            return "Metal Performance Shader"
        }
    }
}

extension Examples {
    var view: some View {
        switch self {
        case .camera:
            return AnyView(CameraSampleView())
        case .segmentation:
            return AnyView(SegmentationSampleView())
        case .MPS:
            return AnyView(MPSSampleView())
        case .lookup:
            return AnyView(LookupFilterView())
        default:
            return AnyView(Text(self.name))
        }
    }
}

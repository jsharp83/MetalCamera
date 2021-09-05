//
//  ExampleViewModel.swift
//  Example
//
//  Created by Eunchul Jeon on 2021/09/05.
//

import Foundation

enum Examples: Int, CaseIterable, Identifiable {
    case camera
    case segmentation
    case lookup
    case MPS
    
    var id: String {
        return "\(self.rawValue)"
    }
    
    var name: String {
        switch self {
        case .camera:
            return "Camera, Composition and Recording"
        case .segmentation:
            return "Segmentation"
        case .lookup:
            return "Lookup Table"
        case .MPS:
            return "Metal Performance Shader"
        }
    }
}

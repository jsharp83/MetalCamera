//
//  StabilityCheckViewModel.swift
//  Example
//
//  Created by  Eric on 2021/12/31.
//

import MetalCamera
import UIKit

enum SceneStabilityResult: String {
    case unknown
    case stable
    case unstable
}

class StabilityCheckViewModel: ObservableObject {
    let camera = try! MetalCamera(position: .back ,videoOrientation: .portrait, isVideoMirrored: false)
    let translationHandler = TranslationHandler()
    private let sceneStabilityRequiredHistoryLength = 15
    private var sceneStabilityHistoryPoints = [CGPoint]()
    
    @Published var operationChain: OperationChain?
    @Published var stability = SceneStabilityResult.unknown
    @Published var translationPoint: CGPoint = .zero
    
    init() {
        camera-->translationHandler
        operationChain = translationHandler
        translationHandler.translationCallback = updateTranslation
    }
    
    private func updateTranslation(_ translation: CGAffineTransform) {
        let point = CGPoint(x: translation.tx, y: translation.ty)

        sceneStabilityHistoryPoints.append(point)
        
        guard sceneStabilityHistoryPoints.count > sceneStabilityRequiredHistoryLength else {
            return
        }
        
        var movingAverage = CGPoint.zero
        movingAverage.x = sceneStabilityHistoryPoints.map { $0.x }.reduce(.zero, +)
        movingAverage.y = sceneStabilityHistoryPoints.map { $0.y }.reduce(.zero, +)
        let distance = abs(movingAverage.x) + abs(movingAverage.y)
        
        sceneStabilityHistoryPoints.removeFirst()

        DispatchQueue.main.async {
            self.translationPoint = point
            self.stability = distance < 100 ? .stable : .unstable
        }
    }
}

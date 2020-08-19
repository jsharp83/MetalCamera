//
//  PoseNetOutput.swift
//  MetalCamera
//
//  Created by Eric on 2020/08/14.
//

import Foundation
import CoreML
import Vision

public struct PoseNetOutput {
    enum Feature: String {
        case heatmap = "heatmap"
        case offsets = "offsets"
        case backwardDisplacementMap = "displacementBwd"
        case forwardDisplacementMap = "displacementFwd"
    }

    private(set) var heatmap: MLMultiArray!
    private(set) var offsets: MLMultiArray!
    private(set) var backwardDisplacementMap: MLMultiArray!
    private(set) var forwardDisplacementMap: MLMultiArray!

    var height: Int {
        return heatmap.shape[1].intValue
    }

    /// Returns the **width** of the output array (`heatmap.shape[2]`).
    var width: Int {
        return heatmap.shape[2].intValue
    }

    /// The PoseNet model's output stride.
    ///
    /// Valid strides are 16 and 8 and define the resolution of the grid output by the model. Smaller strides
    /// result in higher-resolution grids with an expected increase in accuracy but require more computation. Larger
    /// strides provide a more coarse grid and typically less accurate but are computationally cheaper in comparison.
    ///
    /// - Note: The output stride is dependent on the chosen model and specified in the metadata. Other variants of the
    /// PoseNet models are available from the Model Gallery.
    let modelOutputStride: Int = 16

    init(_ predictionResult: [VNCoreMLFeatureValueObservation]) {
        for result in predictionResult {
            if let feature = Feature(rawValue: result.featureName) {
                switch feature {
                case .heatmap:
                    self.heatmap = result.featureValue.multiArrayValue
                case .offsets:
                    self.offsets = result.featureValue.multiArrayValue
                case .backwardDisplacementMap:
                    self.backwardDisplacementMap = result.featureValue.multiArrayValue
                case .forwardDisplacementMap:
                    self.forwardDisplacementMap = result.featureValue.multiArrayValue
                }
            }
        }
    }

    struct Cell {
        let yIndex: Int
        let xIndex: Int

        init(_ yIndex: Int, _ xIndex: Int) {
            self.yIndex = yIndex
            self.xIndex = xIndex
        }

        static var zero: Cell {
            return Cell(0, 0)
        }
    }

    func offset(for jointName: Joint.Name, at cell: Cell) -> CGVector {
        // Create the index for the y and x component of the offset.
        let yOffsetIndex = [jointName.rawValue, cell.yIndex, cell.xIndex]
        let xOffsetIndex = [jointName.rawValue + Joint.numberOfJoints, cell.yIndex, cell.xIndex]

        // Obtain y and x component of the offset from the offsets array.
        let offsetY: Double = offsets[yOffsetIndex].doubleValue
        let offsetX: Double = offsets[xOffsetIndex].doubleValue

        return CGVector(dx: CGFloat(offsetX), dy: CGFloat(offsetY))
    }

    func position(for jointName: Joint.Name, at cell: Cell) -> CGPoint {
        let jointOffset = offset(for: jointName, at: cell)

        // First, calculate the joint’s coarse position.
        var jointPosition = CGPoint(x: cell.xIndex * modelOutputStride,
                                    y: cell.yIndex * modelOutputStride)

        // Then, add the offset to get a precise position.
        jointPosition += jointOffset

        return jointPosition
    }

    func confidence(for jointName: Joint.Name, at cell: Cell) -> Double {
        let multiArrayIndex = [jointName.rawValue, cell.yIndex, cell.xIndex]
        return heatmap[multiArrayIndex].doubleValue
    }
}

extension MLMultiArray {
    subscript(index: [Int]) -> NSNumber {
        return self[index.map { NSNumber(value: $0) } ]
    }
}

extension CGPoint {
    /// Calculates and returns the result of an element-wise addition.
    static func + (_ lhs: CGPoint, _ rhs: CGVector) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    /// Performs element-wise addition.
    static func += (lhs: inout CGPoint, _ rhs: CGVector) {
        lhs.x += rhs.dx
        lhs.y += rhs.dy
    }

    /// Calculates and returns the result of an element-wise multiplication.
    static func * (_ lhs: CGPoint, _ scale: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * scale, y: lhs.y * scale)
    }

    /// Calculates and returns the result of an element-wise multiplication.
    static func * (_ lhs: CGPoint, _ rhs: CGSize) -> CGPoint {
        return CGPoint(x: lhs.x * rhs.width, y: lhs.y * rhs.height)
    }
}

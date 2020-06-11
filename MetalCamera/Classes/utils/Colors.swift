//
//  Colors.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/14.
//

import UIKit

extension UIColor {
    static func randomColor() -> UIColor {
        return UIColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1.0)
    }
}

func generateRandomColors(_ count: Int) -> [[UInt8]] {
    var colors = [[UInt8]]()
    for _ in 0..<count {
        colors.append([UInt8.random(in: 0..<255), UInt8.random(in: 0..<255), UInt8.random(in: 0..<255), 255])
    }
    return colors
}

var randomColors: [[UInt8]] = generateRandomColors(255)

//
//  SampleMainViewController.swift
//  MetalCamera_Example
//
//  Created by Eric on 2020/06/11.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class SampleMainViewController: UITableViewController {
    let samples: [(title: String, identifier: String)] = [
        ("Camera, Composition and Recording","CameraSampleViewController"),
        ("Segmentation","SegmentationSampleViewController"),
        ("Lookup Table", "LookupTableSampleViewController"),
        ("PoseNet", "PoseNetSampleViewController"),
        ("Metal Performance Shader", "MPSSampleViewController")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "SampleMainVC"
    }
}

extension SampleMainViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return samples.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SampleCell") else {
            fatalError("Check cell identifier")
        }
        cell.textLabel?.text = samples[indexPath.row].title

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: samples[indexPath.row].identifier)
        navigationController?.pushViewController(vc, animated: true)
    }
}

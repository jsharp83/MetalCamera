//
//  CoreMLLoader.swift
//  MetalCamera
//
//  Created by Eric on 2020/06/10.
//

import Foundation
import CoreML

enum CoreMLLoaderError: Error {
    case invalidFileName
    case compileFailed
    case loadFailed
    case removeExistFileFailed
}

public class CoreMLLoader {
    private let url: URL
    private let filePath: String
    private let isForcedDownload: Bool
    private var fileURL: URL {
        let documentsDir = try? FileManager.default.url(for:. documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = URL(string: filePath, relativeTo: documentsDir)!
        return fileURL
    }
    private var progressObservation: NSKeyValueObservation?

    public init(url: URL, filePath: String? = nil, isForcedDownload: Bool = false) throws {
        self.url = url
        self.isForcedDownload = isForcedDownload

        let lastCompoent = url.lastPathComponent
        guard lastCompoent.hasSuffix(".mlmodel") else {
            throw CoreMLLoaderError.invalidFileName
        }

        if let filePath = filePath {
            self.filePath = filePath
        } else {
            self.filePath = "CoreMLModel/\(lastCompoent)"
        }
    }

    // TODO: Cancel and handling background process are needed.
    public func load(_ progressHandler: ((Double) -> Void)? = nil,
                     _ completionHandler: @escaping ((MLModel?, Error?) -> Void)) {
        if isForcedDownload {
            do {
                try FileManager.default.removeItem(atPath: fileURL.path)
            } catch {
                completionHandler(nil, CoreMLLoaderError.removeExistFileFailed)
                return
            }
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            loadCoreML(completionHandler)
        } else {
            prepareDownloadFolder()

            let task = URLSession.shared.downloadTask(with: url) { (url, response, error) in
                if let path = url?.path {
                    try! FileManager.default.moveItem(atPath: path, toPath: self.fileURL.path)
                }
                self.progressObservation?.invalidate()
                self.progressObservation = nil

                self.loadCoreML(completionHandler)
            }

            progressObservation = task.progress.observe(\.fractionCompleted) { (progress, value) in
                progressHandler?(progress.fractionCompleted)
            }

            task.resume()
        }
    }

    private func loadCoreML(_ completionHandler: ((MLModel?, Error?) -> Void)) {
        guard let compiledModelURL = try? MLModel.compileModel(at: fileURL) else {
            completionHandler(nil, CoreMLLoaderError.compileFailed)
            return
        }

        if let model = try? MLModel(contentsOf: compiledModelURL) {
            completionHandler(model, nil)
        } else {
            completionHandler(nil, CoreMLLoaderError.loadFailed)
        }
    }

    private func prepareDownloadFolder() {
        let directoryURL = fileURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

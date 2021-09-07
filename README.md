# MetalCamera

<!--
[![CI Status](https://img.shields.io/travis/jsharp83/MetalCamera.svg?style=flat)](https://travis-ci.org/jsharp83/MetalCamera)
-->
[![Version](https://img.shields.io/cocoapods/v/MetalCamera.svg?style=flat)](https://cocoapods.org/pods/MetalCamera)
[![License](https://img.shields.io/cocoapods/l/MetalCamera.svg?style=flat)](https://cocoapods.org/pods/MetalCamera)
[![Platform](https://img.shields.io/cocoapods/p/MetalCamera.svg?style=flat)](https://cocoapods.org/pods/MetalCamera)

## Motivation
MetalCamera is an open source project for performing GPU-accelerated image and video processing on Mac and iOS. 

There are many ways to use the GPU, including CIFilter, but it's not open or difficult to expand feature and contribute.

The main goal of this repository is to provide an interface and test performance to develop and apply it to actual services more easily when you have an idea about image processing and machine learning in the iOS environment.

At this stage, I'm developing to provide the following functions simply.
* SwiftUI support
* Camera input/output Handling
* Save image frame to video
* Basic image processing and filter
* Download and processing CoreML model
* Visualize result of CoreML model
* Benchmark algorithm.


There are still a lot of bugs and many things to implement, 
but I created a repository because I wanted to develop camera and vision feature in iOS with many people.

Feel free to use, make some issue and PR when you have a idea.

Thanks.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

### Camera
* SwiftUI case
```swift
import SwiftUI
import MetalCamera

struct CameraSampleView: View {
    let camera = try! MetalCamera(videoOrientation: .portrait, isVideoMirrored: true)
    var body: some View {
        VideoPreview(operation: camera)
            .onAppear {
                camera.startCapture()
            }
            .onDisappear {
                camera.stopCapture()
            }
    }
}
```

* UIKit case
```swift    
import MetalCamera    
@IBOutlet weak var preview: MetalVideoView!
var camera: MetalCamera!
    
override func viewDidLoad() {
    super.viewDidLoad()
    guard let camera = try? MetalCamera(useMic: useMic) else { return }
    camera-->preview
    self.camera = camera
}
    
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    camera?.startCapture()
}

override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    camera?.stopCapture()
}    
```

### Download and load CoreML from web url
```swift

import MetalCamera  

let url = URL(string: "https://ml-assets.apple.com/coreml/models/Image/ImageSegmentation/DeepLabV3/DeepLabV3Int8LUT.mlmodel")!

do {
    coreMLLoader = try CoreMLLoader(url: url, isForcedDownload: true)
    coreMLLoader?.load({ (progress) in
        debugPrint("Model downloading.... \(progress)")
    }, { (loadedModel, error) in
        if let loadedModel = loadedModel {
            debugPrint(loadedModel)
        } else if let error = error {
            debugPrint(error)
        }
    })
} catch {
    debugPrint(error)
}
```

### Segmentation Test(DeepLabV3Int8LUT model, iPhone XS, avg 63ms)
![Segmentation](https://user-images.githubusercontent.com/160281/85217231-5e4b1a00-b3c9-11ea-9317-7df77de33cf3.gif)

```swift
func loadCoreML() {
    do {
        let modelURL = URL(string: "https://ml-assets.apple.com/coreml/models/Image/ImageSegmentation/DeepLabV3/DeepLabV3Int8LUT.mlmodel")!    
        let loader = try CoreMLLoader(url: modelURL)
        loader.load { [weak self](model, error) in
            if let model = model {
                self?.setupModelHandler(model)
            } else if let error = error {
                debugPrint(error)
            }
        }
    } catch {
        debugPrint(error)
    }
}

func setupModelHandler(_ model: MLModel) {
    do {
        let modelHandler = try CoreMLClassifierHandler(model)
        camera.removeTarget(preview)
        camera-->modelHandler-->preview
    } catch{
        debugPrint(error)
    }
}
```

### Composite images or video and Rotation
![demo](https://user-images.githubusercontent.com/160281/85217243-7327ad80-b3c9-11ea-9162-d29c8aa1864e.gif)

```swift
let rotation90 = RotationOperation(.degree90_flip)

let imageCompositor = ImageCompositor(baseTextureKey: camera.textureKey)
guard let testImage = UIImage(named: "sampleImage") else {
    fatalError("Check image resource")
}

let gray = Gray()

let compositeFrame = CGRect(x: 50, y: 100, width: 250, height: 250)
imageCompositor.addCompositeImage(testImage)
imageCompositor.sourceFrame = compositeFrame

videoCompositor = ImageCompositor(baseTextureKey: camera.textureKey)
videoCompositor.sourceFrame = CGRect(x: 320, y: 100, width: 450, height: 250)

camera-->rotation90-->gray-->imageCompositor-->videoCompositor-->preview

```

### Filter

* Lookup Filter

![lookup](https://user-images.githubusercontent.com/160281/85217209-29d75e00-b3c9-11ea-9c5b-ad448654df79.gif)

### Recording video and audio
```swift
do {
    if FileManager.default.fileExists(atPath: recordingURL.path) {
        try FileManager.default.removeItem(at: recordingURL)
    }
     
    recorder = try MetalVideoWriter(url: recordingURL, videoSize: CGSize(width: 720, height: 1280), recordAudio: useMic)
    if let recorder = recorder {
        preview-->recorder
        if useMic {
            camera==>recorder
        }                   
                   
        recorder.startRecording()

    }
} catch {
    debugPrint(error)
}
```

## Requirements
* Swift 5
* Xcode 12.5.1 or higher on Mac
* iOS: 14.0 or higher

## Installation

MetalCamera is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MetalCamera'
```

## References

When creating this repository, I referenced the following repositories a lot. 
First of all, thanks to those who have worked and opened many parts in advance, and let me know if there are any problems.

* [GPUImage3](https://github.com/BradLarson/GPUImage3)
* [MaLiang](https://github.com/Harley-xk/MaLiang)
* [CoreMLHelpers](https://github.com/hollance/CoreMLHelpers)
* [MetalPetal](https://github.com/MetalPetal/MetalPetal)

## Author

jsharp83, jsharp83@gmail.com

## License

MetalCamera is available under the MIT license. See the LICENSE file for more info.

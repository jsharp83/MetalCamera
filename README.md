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

There are still a lot of bugs and many things to implement, 
but I created a repository because I wanted to develop camera and vision feature in iOS with many people.

Feel free to use, make some issue and PR when you have a idea.

Thanks.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

### Camera
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

### Composite images or video and Rotation
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
TBD

### Recording video and audio
![demo](./docs/record_sample.gif)

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
* Swift 4
* Xcode 11.5 or higher on Mac
* iOS: 13.0 or higher

## Installation

MetalCamera is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'MetalCamera'
```

## References

When creating this repository, I referenced the following repositories a lot. 
First of all, thanks to those who have worked and opened many parts, and let me know if there are any problems.

* [GPUImage3](https://github.com/BradLarson/GPUImage3)
* [MaLiang](https://github.com/Harley-xk/MaLiang)
* [CoreMLHelpers](https://github.com/hollance/CoreMLHelpers)
* [MetalPetal](https://github.com/MetalPetal/MetalPetal)

## Author

jsharp83, jsharp83@gmail.com

## License

MetalCamera is available under the MIT license. See the LICENSE file for more info.

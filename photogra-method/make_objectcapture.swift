import Foundation
import os
import RealityKit

let arguments = ProcessInfo.processInfo.arguments
if arguments.count < 2 {
    //print("make-objectcapture [detail(preview|reduced(default)|medium|full|raw)] [img input dir] [usdz output fn]")
    print("make-objectcapture [img input dir] (detail(preview|reduced|medium|full|raw))")
    Foundation.exit(1)
}
/*
 https://developer.apple.com/documentation/realitykit/photogrammetrysession/request/detail
Triangles  Estimated File Size
.preview <25k <5MB     1024 x 1024     10.666667 MB
.reduced <50k <10MB     2048 x 2048     42.666667 MB
.medium <100k <30MB     4096 x 4096     170.666667 MB
.full <250k <100MB     8192 x 8192     853.33333 MB
.raw <30M  Varies     8192 x 8192 (multiple)     Varies
 //let detail = PhotogrammetrySession.Request.Detail.preview // 2.4MB(onojo)
 //let detail = PhotogrammetrySession.Request.Detail.reduced // 13.5MB(onojo)
 //let detail = PhotogrammetrySession.Request.Detail.medium // 42MB(onojo)
 */
let sdetail = arguments.count > 2 ? arguments[2] : "reduced"
private func getDetail() -> PhotogrammetrySession.Request.Detail {
    switch (sdetail) {
        case "preview":
            return PhotogrammetrySession.Request.Detail.preview
        case "reduced":
            return PhotogrammetrySession.Request.Detail.reduced
        case "medium":
            return PhotogrammetrySession.Request.Detail.medium
        case "full":
            return PhotogrammetrySession.Request.Detail.full
        case "raw":
            return PhotogrammetrySession.Request.Detail.raw
        default:
            print("unsupported detail")
            Foundation.exit(1)
    }
}

let detail = getDetail()

let inputFolder = arguments[1]
let outputFilename = inputFolder + ".usdz"

let inputFolderUrl = URL(fileURLWithPath: inputFolder, isDirectory: true)
var configure = PhotogrammetrySession.Configuration()
configure.sampleOrdering = PhotogrammetrySession.Configuration.SampleOrdering.unordered
//configure.featureSensitivity = PhotogrammetrySession.Configuration.FeatureSensitivity.high // The session uses a slower, more sensitive algorithm to detect landmarks.
configure.featureSensitivity = PhotogrammetrySession.Configuration.FeatureSensitivity.normal // The session uses the default algorithm to detect landmarks.

let session = try PhotogrammetrySession(
    input: inputFolderUrl,
    configuration: configure
)

let waiter = Task {
    for try await output in session.outputs {
        switch output {
            case .processingComplete:
                print("complete!!")
                Foundation.exit(0)
            case .inputComplete:
                print("Output: inputComplete")
            case .requestError(let r, let s):
                print("Output: requestError \(r) \(s)")
            case .requestComplete(_, _):
                print("Output: requestComplete")
            case .requestProgress(_, fractionComplete: let fractionComplete):
                let progress = String(format: "%.2f", fractionComplete * 100)
                print("Output: requestProgress \(progress)%")
            case .processingCancelled:
                print("Output: processingCancelled")
            case .invalidSample(id: _, reason: _):
                print("Output: invalidSample")
            case .skippedSample(id: _):
                print("Output: automatskippedSample")
            case .automaticDownsampling:
                print("Output: automaticDownsampling")
            @unknown default:
                print("Output: unhandled message")
        }
    }
}

private func makeRequest() -> PhotogrammetrySession.Request {
    let outputUrl = URL(fileURLWithPath: outputFilename)
    return PhotogrammetrySession.Request.modelFile(url: outputUrl, detail: detail)
}

withExtendedLifetime((session, waiter)) {
    do {
        let request = makeRequest()
        print("Using request: \(String(describing: request))")
        try session.process(requests: [ request ])
        RunLoop.main.run()
    } catch {
        print("Process got error: \(String(describing: error))")
        Foundation.exit(1)
    }
}

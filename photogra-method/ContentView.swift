//
//  ContentView.swift
//  photogra-method
//
//  Created by Taisuke Fukuno on 2022/02/19.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var file: String = "変換元フォルダ or 動画ファイル"
    @State var message: String = "変換中のメッセージ"
    @State private var seldetail = "reduced"
    let details = ["preview", "reduced", "medium", "full", "raw"]
    @State private var selsensitivity = "high"
    let sensitivities = ["normal", "high"]
    @State private var selorder = "sequential"
    let orders = ["sequential", "unordered"]
    @State private var selfps = "2"
    let fpss = ["0.1", "0.5", "1", "2", "3", "5", "10", "24", "30", "60"]
 

    var body: some View {
        VStack(spacing: 20) {
            ///Image(systemName: "plus")
            Text("いろんな角度からの写真が入ったフォルダか動画をここにドロップ")
                //.lineLimit(nil)
                //.fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                //.background(Color.white)
                .border(Color.black)
            /*
                .onDrop(of: [.fileURL, .item], isTargeted: nil, perform: {
                    providers, _ in

                    #if os(iOS)
                        providers.first!.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) {
                            url, _ in
                            message = describeDroppedURL(url!, detail: seldetail, ContentView.self)
                        }
                    #else
                        
                        _ = providers.first!.loadObject(ofClass: NSPasteboard.PasteboardType.self) {
                            pasteboardItem, _ in
                            message = describeDroppedURL(
                                URL(string: pasteboardItem!.rawValue)!,
                                detail: seldetail,
                                sensitivity: selsensitivity,
                                order: selorder,
                                fps: selfps,
                                view: self
                            )
                        }
             */
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        if let loadableProvider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
                            _ = loadableProvider.loadObject(ofClass: URL.self) { fileURL, _ in
                                DispatchQueue.global().async {
                                    //importer.open(zipArchiveURL: fileURL)
                                    message = describeDroppedURL(
                                        URL(string: fileURL!.absoluteString)!,
                                        detail: seldetail,
                                        sensitivity: selsensitivity,
                                        order: selorder,
                                        fps: selfps,
                                        view: self
                                    )

                                }
                            }
                            return true
                        }
                        return false
                    }
//                #endif

            Text(file)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                //.background(Color.white)
                .border(Color.black)
                //.frame(width: 500, alignment: .center)
            
            Text(message)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                //.background(Color.white)
                .border(Color.black)
                //.frame(width: 500, alignment: .center)
            
            Picker("3Dモデルの解像度", selection: $seldetail) {
                ForEach(details, id: \.self) {
                    Text($0)
                }
            }
            Picker("位置推定精度", selection: $selsensitivity) {
                ForEach(sensitivities, id: \.self) {
                    Text($0)
                }
            }
            Picker("画像連続性", selection: $selorder) {
                ForEach(orders, id: \.self) {
                    Text($0)
                }
            }
            Picker("1秒あたりの静止画枚数（動画用）", selection: $selfps) {
                ForEach(fpss, id: \.self) {
                    Text($0)
                }
            }

            /*
            Button(action: {
                let url = FileManager.default.currentDirectoryPath
                NSWorkspace.shared.open(URL(fileURLWithPath: "\(url)"))
            }) {
                Text("生成した3Dモデルファイルができるフォルダを開く")
            }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            */
        } .padding()
    }
}

func describeDroppedURL(_ url: URL, detail: String, sensitivity: String, order: String, fps: String, view: ContentView) -> String {
    var messageRows: [String] = []
    /*
    if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == false {
        messageRows.append("Dropped file named `\(url.lastPathComponent)`")

        messageRows.append("  which starts with `\(try String(contentsOf: url).components(separatedBy: "\n")[0]))`")
    } else {
        */
        messageRows.append("Dropped folder named `\(url.lastPathComponent)`")
        
        makeObjectCapture(url: url, detail: detail, sensitivity: sensitivity, order: order, fps: fps, view: view)
        //messageRows.append("\(res)")
        /*
        for childUrl in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: []) {
            messageRows.append("  Containing file named `\(childUrl.lastPathComponent)`")

            messageRows.append("    which starts with `\((try String(contentsOf: childUrl)).components(separatedBy: "\n")[0])`")
        }
         */
    //}

    return messageRows.joined(separator: "\n")
}

import Foundation
import os
import RealityKit

//let videoPath = "/Volumes/Untitled/DCIM/100MEDIA/DJI_0796.MP4"
//let videoPath = "/Users/fukuno/Downloads/week-test/DJI_0798.MP4"
//let videoPath = "/Users/fukuno/Library/Containers/jp.jig.fukuno.photogra-method/Data/DJI_0798.MP4"
//let outputFolder = "/Users/fukuno/Downloads/week-test/"
let fps = 2

func runCommand(path: String, arguments: [String]) -> String? {
    let task = Process()
    task.launchPath = path
    task.arguments = arguments
    //task.launchPath = "/bin/bash"
    // task.arguments = ["-c", path] + arguments
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)
    
    return output
}

func convertVideoToJPEG(videoPath: String, outputFolder: String, fps: String) {
    let command = "/opt/homebrew/bin/ffmpeg"
    //let command = "ffmpeg"
    let arguments = [
        "-i",
        videoPath,
        "-qmin",
        "1",
        "-q",
        "1",
        "-r",
        fps,
        "\(outputFolder)/%04d.jpg"
    ]
    
    let res = runCommand(path: command, arguments: arguments)
    print(res ?? "no res")
}

func makeObjectCaptureFromFolder(url: URL, detail: String, sensitivity: String, order: String, view: ContentView) {
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
    //let sdetail = "reduced"
    func getDetail() -> PhotogrammetrySession.Request.Detail {
        switch (detail) {
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
    func getSensitivity() -> PhotogrammetrySession.Configuration.FeatureSensitivity {
        switch (sensitivity) {
            case "high":
                return PhotogrammetrySession.Configuration.FeatureSensitivity.high // The session uses a slower, more sensitive algorithm to detect landmarks.
            default:
                return PhotogrammetrySession.Configuration.FeatureSensitivity.normal // The session uses the default algorithm to detect landmarks.
        }
    }
    func getOrder() -> PhotogrammetrySession.Configuration.SampleOrdering {
        switch (order) {
            case "sequential":
                return PhotogrammetrySession.Configuration.SampleOrdering.sequential
            default:
                return PhotogrammetrySession.Configuration.SampleOrdering.unordered
        }
    }

    let detail = getDetail()
    let sensitivity = getSensitivity()
    let order = getOrder()
    
    //let inputFolder = url.absoluteString // arguments[1]
    let inputFolder = String(url.deletingLastPathComponent().absoluteString.dropFirst(7)) + url.lastPathComponent + "/"
    let outputFilename = String(url.deletingLastPathComponent().absoluteString.dropFirst(7)) + url.lastPathComponent + ".usdz"
    //let outputFilename = url.lastPathComponent + ".usdz" // for default directory
    //let inputFolder = "/Users/fukuno/data/photo/house/img1/"
    //let outputFilename = "/Users/fukuno/data/photo/house/img1-test.usdz"
    print(inputFolder)
    print(outputFilename)
    view.file = inputFolder

    let inputFolderUrl = URL(fileURLWithPath: inputFolder, isDirectory: true)
    let outputUrl = URL(fileURLWithPath: outputFilename, isDirectory: false)
    print(FileManager.default.currentDirectoryPath)
    var configure = PhotogrammetrySession.Configuration()
    configure.sampleOrdering = order
    configure.featureSensitivity = sensitivity
    
    do {
        guard PhotogrammetrySession.isSupported else {
            // Inform user and don't proceed with reconstruction.
            print("not supported PhotogrammetrySession")
            return
        }
        let session = try PhotogrammetrySession(
            input: inputFolderUrl,
            configuration: configure
        )

        let waiter = Task {
            for try await output in session.outputs {
                switch output {
                    case .processingComplete:
                        print("complete!!")
                        //Foundation.exit(0)
                    case .inputComplete:
                        print("Output: inputComplete")
                    case .requestError(let r, let s):
                        print("Output: requestError \(r) \(s)")
                        view.message = "変換中にエラーが発生しました \(r) \(s)"
                    
                    case .requestComplete(_, _):
                        print("Output: requestComplete")
                        view.message = "変換完了！"
                        NSWorkspace.shared.open(outputUrl)

                    case .requestProgress(_, fractionComplete: let fractionComplete):
                        let progress = String(format: "%.2f", fractionComplete * 100)
                        print("Output: requestProgress \(progress)%")
                        view.message = "進捗率 \(progress)%"
                    case .processingCancelled:
                        print("Output: processingCancelled")
                    case .invalidSample(id: _, reason: _):
                        print("Output: invalidSample")
                    case .skippedSample(id: _):
                        print("Output: automatskippedSample")
                    case .automaticDownsampling:
                        print("Output: automaticDownsampling")
                    //case .requestProgressInfo(_, _):
                    //    break;
                @unknown default:
                        print("Output: unhandled message")
                }
            }
        }

        func makeRequest() -> PhotogrammetrySession.Request {
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
    } catch let e {
        print(e)
    }
}


func makeObjectCapture(url: URL, detail: String, sensitivity: String, order: String, fps: String, view: ContentView) {
    let imageExtensions = ["mov", "mp4", "avi"]
    if imageExtensions.contains(url.pathExtension.lowercased()) {
        let videoPath = String(url.deletingLastPathComponent().absoluteString.dropFirst(7)) + url.lastPathComponent
        print(videoPath)
        let outputFolder = String(videoPath.dropLast(url.pathExtension.count + 1))
        
        // mkdir
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: outputFolder)
        } catch _ {
            //print(e)
        }
        do {
            try fileManager.createDirectory(atPath: outputFolder, withIntermediateDirectories: true, attributes: nil)
        } catch let e {
            print(e)
        }
        view.file = videoPath
        view.message = "動画を静止画に変換中..."
        convertVideoToJPEG(videoPath: videoPath, outputFolder: outputFolder, fps: fps)
        let url2 = URL(fileURLWithPath: outputFolder)
        print(url2)
        makeObjectCaptureFromFolder(url: url2, detail: detail, sensitivity: sensitivity, order: order, view: view)
    } else {
        makeObjectCaptureFromFolder(url: url, detail: detail, sensitivity: sensitivity, order: order, view: view)
    }
}


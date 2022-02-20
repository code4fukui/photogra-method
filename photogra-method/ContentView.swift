//
//  ContentView.swift
//  photogra-method
//
//  Created by Taisuke Fukuno on 2022/02/19.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var file: String = "変換元フォルダ"
    @State var message: String = "変換中のメッセージ"

    var body: some View {
        VStack(spacing: 20) {
            ///Image(systemName: "plus")
            Text("いろんな角度からの写真が入ったフォルダを\nここにドロップすると変換スタート！")
                //.lineLimit(nil)
                //.fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.white)
                .onDrop(of: [.fileURL, .item], isTargeted: nil, perform: {
                    providers, _ in

                    #if os(iOS)
                        providers.first!.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) {
                            url, _ in
                            message = describeDroppedURL(url!, ContentView.self)
                        }
                    #else
                        _ = providers.first!.loadObject(ofClass: NSPasteboard.PasteboardType.self) {
                            pasteboardItem, _ in
                            message = describeDroppedURL(URL(string: pasteboardItem!.rawValue)!, view: self)
                        }
                    #endif

                    return true
                })
            Text(file)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.white)
                .border(Color.black)
                //.frame(width: 500, alignment: .center)
            
            Text(message)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.white)
                .border(Color.black)
                //.frame(width: 500, alignment: .center)

            Button(action: {
                let url = FileManager.default.currentDirectoryPath
                NSWorkspace.shared.open(URL(fileURLWithPath: "\(url)"))
            }) {
                Text("生成した3Dモデルファイルができるフォルダを開く")
            }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } .padding()
    }
}

func describeDroppedURL(_ url: URL, view: ContentView) -> String {
    do {
        var messageRows: [String] = []

        if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == false {
            messageRows.append("Dropped file named `\(url.lastPathComponent)`")

            messageRows.append("  which starts with `\(try String(contentsOf: url).components(separatedBy: "\n")[0]))`")
        } else {
            messageRows.append("Dropped folder named `\(url.lastPathComponent)`")
            
            makeObjectCapture(url: url, view: view)
            //messageRows.append("\(res)")
            /*
            for childUrl in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: []) {
                messageRows.append("  Containing file named `\(childUrl.lastPathComponent)`")

                messageRows.append("    which starts with `\((try String(contentsOf: childUrl)).components(separatedBy: "\n")[0])`")
            }
             */
        }

        return messageRows.joined(separator: "\n")
    } catch {
        return "Error: \(error)"
    }
}

import Foundation
import os
import RealityKit

func makeObjectCapture(url: URL, view: ContentView) {

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
    let sdetail = "reduced"
    func getDetail() -> PhotogrammetrySession.Request.Detail {
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

    //let inputFolder = url.absoluteString // arguments[1]
    let inputFolder = String(url.deletingLastPathComponent().absoluteString.dropFirst(7)) + url.lastPathComponent + "/"
    //let outputFilename = String(url.deletingLastPathComponent().absoluteString.dropFirst(7)) + url.lastPathComponent + ".usdz"
    let outputFilename = url.lastPathComponent + ".usdz"
    //let inputFolder = "/Users/fukuno/data/photo/house/img1/"
    //let outputFilename = "/Users/fukuno/data/photo/house/img1-test.usdz"
    print(inputFolder)
    print(outputFilename)
    view.file = inputFolder

    let inputFolderUrl = URL(fileURLWithPath: inputFolder, isDirectory: true)
    let outputUrl = URL(fileURLWithPath: outputFilename, isDirectory: false)
    print(FileManager.default.currentDirectoryPath)
    var configure = PhotogrammetrySession.Configuration()
    configure.sampleOrdering = PhotogrammetrySession.Configuration.SampleOrdering.unordered
    //configure.featureSensitivity = PhotogrammetrySession.Configuration.FeatureSensitivity.high // The session uses a slower, more sensitive algorithm to detect landmarks.
    configure.featureSensitivity = PhotogrammetrySession.Configuration.FeatureSensitivity.normal // The session uses the default algorithm to detect landmarks.
    
    do {
            
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


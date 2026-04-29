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
    @State private var isDropTargeted = false
    @State private var seldetail = "reduced"
    let details = ["preview", "reduced", "medium", "full", "raw"]
    @State private var selsensitivity = "high"
    let sensitivities = ["normal", "high"]
    @State private var selorder = "sequential"
    let orders = ["sequential", "unordered"]
    @State private var selfps = "2"
    let fpss = ["0.1", "0.5", "1", "2", "3", "5", "10", "24", "30", "60"]
 

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("photogra-method")
                    .font(.title2.weight(.semibold))
                Text("写真フォルダまたは動画からUSDZモデルを生成")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            dropArea

            GroupBox("状態") {
                VStack(alignment: .leading, spacing: 10) {
                    statusRow(title: "入力", value: file)
                    Divider()
                    statusRow(title: "進捗", value: message)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            HStack(alignment: .top, spacing: 14) {
                GroupBox("動画") {
                    optionPicker("静止画枚数 / 秒", selection: $selfps, values: fpss)
                }

                GroupBox("3Dモデル") {
                    VStack(alignment: .leading, spacing: 12) {
                        optionPicker("解像度", selection: $seldetail, values: details)
                        optionPicker("位置推定精度", selection: $selsensitivity, values: sensitivities)
                        optionPicker("画像連続性", selection: $selorder, values: orders)
                    }
                }
            }
        }
        .padding(22)
        .frame(minWidth: 560, idealWidth: 640, maxWidth: .infinity, minHeight: 430, alignment: .topLeading)
    }

    private var dropArea: some View {
        HStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(isDropTargeted ? .accentColor : .secondary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("ここにドロップ")
                    .font(.headline)
                Text("写真が入ったフォルダ、またはMOV / MP4 / AVI")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                Text(value)
                    .font(.body.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
    }

    private func optionPicker(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        Picker(title, selection: selection) {
            ForEach(values, id: \.self) {
                Text($0)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        if let loadableProvider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
            _ = loadableProvider.loadObject(ofClass: URL.self) { fileURL, _ in
                guard let fileURL else {
                    Task { @MainActor in
                        message = "ファイルを読み込めませんでした"
                    }
                    return
                }

                Task { @MainActor in
                    let detail = seldetail
                    let sensitivity = selsensitivity
                    let order = selorder
                    let fps = selfps

                    Task.detached(priority: .userInitiated) {
                        await processDroppedURL(
                            fileURL,
                            detail: detail,
                            sensitivity: sensitivity,
                            order: order,
                            fps: fps,
                            onFileChange: { newFile in
                                await MainActor.run {
                                    file = newFile
                                }
                            },
                            onMessageChange: { newMessage in
                                await MainActor.run {
                                    message = newMessage
                                }
                            }
                        )
                    }
                }
            }
            return true
        }
        return false
    }
}

func processDroppedURL(
    _ url: URL,
    detail: String,
    sensitivity: String,
    order: String,
    fps: String,
    onFileChange: @escaping @Sendable (String) async -> Void,
    onMessageChange: @escaping @Sendable (String) async -> Void
) async {
    await onMessageChange("ドロップ: \(url.lastPathComponent)")
    await makeObjectCapture(
        url: url,
        detail: detail,
        sensitivity: sensitivity,
        order: order,
        fps: fps,
        onFileChange: onFileChange,
        onMessageChange: onMessageChange
    )
}

import Foundation
import os
import RealityKit

//let videoPath = "/Volumes/Untitled/DCIM/100MEDIA/DJI_0796.MP4"
//let videoPath = "/Users/fukuno/Downloads/week-test/DJI_0798.MP4"
//let videoPath = "/Users/fukuno/Library/Containers/jp.jig.fukuno.photogra-method/Data/DJI_0798.MP4"
//let outputFolder = "/Users/fukuno/Downloads/week-test/"
let fps = 2

enum ConversionError: LocalizedError {
    case ffmpegNotFound
    case ffmpegFailed(String)
    case noImagesGenerated(String)

    var errorDescription: String? {
        switch self {
            case .ffmpegNotFound:
                return "ffmpegが見つかりませんでした。Homebrewで `brew install ffmpeg` を実行してください"
            case .ffmpegFailed(let output):
                return "動画の静止画変換に失敗しました: \(output)"
            case .noImagesGenerated(let outputFolder):
                return "静止画が生成されませんでした: \(outputFolder)"
        }
    }
}

func runCommand(path: String, arguments: [String]) throws -> String {
    let task = Process()
    guard FileManager.default.isExecutableFile(atPath: path) else {
        throw ConversionError.ffmpegNotFound
    }
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = arguments
    //task.launchPath = "/bin/bash"
    // task.arguments = ["-c", path] + arguments
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    try task.run()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    guard task.terminationStatus == 0 else {
        throw ConversionError.ffmpegFailed(output)
    }
    
    return output
}

func convertVideoToJPEG(videoPath: String, outputFolder: String, fps: String) throws {
    let command = "/opt/homebrew/bin/ffmpeg"
    //let command = "ffmpeg"
    let arguments = [
        "-y",
        "-i",
        videoPath,
        "-vf",
        "fps=\(fps)",
        "-q:v",
        "1",
        "\(outputFolder)/%04d.jpg"
    ]
    
    let res = try runCommand(path: command, arguments: arguments)
    print(res)
}

func countGeneratedImages(in outputFolder: String) -> Int {
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: outputFolder) else {
        return 0
    }
    let imageExtensions = ["jpg", "jpeg", "png", "heic"]
    return files.filter { imageExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }.count
}

func makeObjectCaptureFromFolder(
    url: URL,
    detail: String,
    sensitivity: String,
    order: String,
    onFileChange: @escaping @Sendable (String) async -> Void,
    onMessageChange: @escaping @Sendable (String) async -> Void
) async {
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
                return PhotogrammetrySession.Request.Detail.reduced
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
    let inputFolder = url.path
    var outputFilename = url.deletingPathExtension().path + ".usdz"
    for i in 2...10000 {
        let checkValidation = FileManager.default
        if (checkValidation.fileExists(atPath: outputFilename)) {
            outputFilename = url.deletingPathExtension().path + "_" + String(i) + ".usdz"
        } else {
            break
        }
    }
    //let outputFilename = url.lastPathComponent + ".usdz" // for default directory
    //let inputFolder = "/Users/fukuno/data/photo/house/img1/"
    //let outputFilename = "/Users/fukuno/data/photo/house/img1-test.usdz"
    print(inputFolder)
    print(outputFilename)
    await onFileChange(inputFolder)

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
            await onMessageChange("PhotogrammetrySessionに対応していません")
            return
        }
        let session = try PhotogrammetrySession(
            input: inputFolderUrl,
            configuration: configure
        )

        var didCompleteRequest = false
        let waiter = Task {
            var finished = false
            for try await output in session.outputs {
                switch output {
                    case .processingComplete:
                        print("complete!!")
                        finished = true
                        //Foundation.exit(0)
                    case .inputComplete:
                        print("Output: inputComplete")
                    case .requestError(let r, let s):
                        print("Output: requestError \(r) \(s)")
                        await onMessageChange("変換中にエラーが発生しました \(r) \(s)")
                        finished = true
                    
                    case .requestComplete(_, _):
                        print("Output: requestComplete")
                        didCompleteRequest = true
                        await onMessageChange("変換完了。メモリを解放中...")
                        await MainActor.run {
                            _ = NSWorkspace.shared.open(outputUrl)
                        }

                    case .requestProgress(_, fractionComplete: let fractionComplete):
                        let progress = String(format: "%.2f", fractionComplete * 100)
                        print("Output: requestProgress \(progress)%")
                        await onMessageChange("進捗率 \(progress)%")
                    case .processingCancelled:
                        print("Output: processingCancelled")
                        await onMessageChange("変換をキャンセルしました")
                        finished = true
                    case .invalidSample(id: _, reason: _):
                        print("Output: invalidSample")
                    case .skippedSample(id: _):
                        print("Output: automatskippedSample")
                    case .automaticDownsampling:
                        print("Output: automaticDownsampling")
                    case .requestProgressInfo(_, _):
                        print("Output: requestProgressInfo")
                    case .stitchingIncomplete:
                        print("Output: stitchingIncomplete")
                    @unknown default:
                        print("Output: unhandled message")
                }
                if finished {
                    break
                }
            }
        }
        defer {
            waiter.cancel()
        }

        func makeRequest() -> PhotogrammetrySession.Request {
            return PhotogrammetrySession.Request.modelFile(url: outputUrl, detail: detail)
        }

        do {
            let request = makeRequest()
            print("Using request: \(String(describing: request))")
            try session.process(requests: [ request ])
        } catch {
            print("Process got error: \(String(describing: error))")
            await onMessageChange("変換中にエラーが発生しました \(error)")
            return
        }

        do {
            try await waiter.value
            if didCompleteRequest {
                await onMessageChange("変換完了！")
            }
        } catch {
            print("Waiter got error: \(String(describing: error))")
            await onMessageChange("変換中にエラーが発生しました \(error)")
        }
    } catch let e {
        print(e)
        await onMessageChange("変換中にエラーが発生しました \(e)")
    }
}


func makeObjectCapture(
    url: URL,
    detail: String,
    sensitivity: String,
    order: String,
    fps: String,
    onFileChange: @escaping @Sendable (String) async -> Void,
    onMessageChange: @escaping @Sendable (String) async -> Void
) async {
    let imageExtensions = ["mov", "mp4", "avi"]
    if imageExtensions.contains(url.pathExtension.lowercased()) {
        let videoPath = url.path
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
        await onFileChange(videoPath)
        await onMessageChange("動画を静止画に変換中...")
        do {
            try convertVideoToJPEG(videoPath: videoPath, outputFolder: outputFolder, fps: fps)
        } catch {
            print(error)
            await onMessageChange(error.localizedDescription)
            return
        }
        let imageCount = countGeneratedImages(in: outputFolder)
        guard imageCount > 0 else {
            let error = ConversionError.noImagesGenerated(outputFolder)
            print(error)
            await onMessageChange(error.localizedDescription)
            return
        }
        await onMessageChange("静止画を\(imageCount)枚生成しました。3Dモデルに変換中...")
        let url2 = URL(fileURLWithPath: outputFolder)
        print(url2)
        await makeObjectCaptureFromFolder(
            url: url2,
            detail: detail,
            sensitivity: sensitivity,
            order: order,
            onFileChange: onFileChange,
            onMessageChange: onMessageChange
        )
    } else {
        await makeObjectCaptureFromFolder(
            url: url,
            detail: detail,
            sensitivity: sensitivity,
            order: order,
            onFileChange: onFileChange,
            onMessageChange: onMessageChange
        )
    }
}

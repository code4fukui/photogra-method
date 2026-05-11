# photogra-method (フォトグラメソッド)

> 日本語のREADMEはこちらです: [README.ja.md](README.ja.md)

A simple macOS app for creating USDZ 3D models from videos or photo folders using Apple's Object Capture API.

Just drag and drop a video file or a folder of images. The app handles the conversion and opens the resulting 3D model automatically.

## Features

- **Drag & Drop Interface**: Simply drop a video file (MOV, MP4, AVI) or a folder of photos to start processing.
- **Video to Photo Conversion**: Automatically extracts frames from video files using `ffmpeg`.
- **Customizable Processing**: Fine-tune the 3D model generation with several options:
    - **Video FPS**: Set the number of frames per second to extract from video input (0.1 to 60).
    - **Model Detail**: Choose the output quality (`preview`, `reduced`, `medium`, `full`, `raw`).
    - **Feature Sensitivity**: Adjust the feature detection sensitivity (`normal`, `high`).
    - **Photo Ordering**: Specify if the input images are `sequential` or `unordered`.
- **Automatic Output**: Generates a USDZ file and opens it in Preview upon completion.

## Requirements

- **macOS**: Monterey (12.1) or later.
- **[Homebrew](https://brew.sh/)**: The Missing Package Manager for macOS.
- **[ffmpeg](https://ffmpeg.org/)**: A command-line tool for handling video and audio.

## Installation & Usage

1.  **Install Dependencies**:
    Open Terminal and install `ffmpeg` using Homebrew.
    ```sh
    brew install ffmpeg
    ```

2.  **Download the App**:
    Download the `photogra-method.app` from the repository.

3.  **Run the App**:
    Drag the video file or photo folder onto the app window. The conversion will start, and the final `.usdz` model will open when finished.

### Note on First Launch

On the first launch, macOS may prevent the app from opening due to security restrictions. To resolve this:

1.  Go to **System Settings** → **Privacy & Security**.
2.  Scroll down to the security section.
3.  You will see a message about "photogra-method" being blocked. Click **"Open Anyway"**.

Alternatively, you can right-click the app icon and select **Open** from the context menu.

## Technology

This application is a wrapper around Apple's [Object Capture API](https://developer.apple.com/jp/augmented-reality/object-capture/), which is part of the RealityKit framework. It is built with SwiftUI.

## Blog Posts & Demos

Read more about the project and see it in action:
- https://fukuno.jig.jp/3494
- https://fukuno.jig.jp/3489
- [福井高専ドローン空撮 (Fukui KOSEN Drone Aerial Photography)](https://fukuno.jig.jp/3522)
- https://fukuno.jig.jp/3910
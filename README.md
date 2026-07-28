# VoiceFlow

A native macOS application for voice processing, built with SwiftUI and powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for local speech recognition.

## Features

- Native macOS app built with SwiftUI
- Local speech recognition using whisper.cpp (no cloud dependency)
- Runs on Apple Silicon
- macOS 14.0+ deployment target

## Requirements

- macOS 14.0 or later
- Apple Silicon (ARM64)
- Xcode 16.0
- Swift 5.9

## Project Structure

```
VoiceFlow/
├── VoiceFlow/          # Main app source code
├── whisper.cpp/        # Whisper C++ library
├── VoiceFlow.xcodeproj/ # Xcode project
├── project.yml         # XcodeGen project specification
└── icon_1024.png       # App icon
```

## Build

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open VoiceFlow.xcodeproj
```

## License

All rights reserved.

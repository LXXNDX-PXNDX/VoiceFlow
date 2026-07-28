# VoiceFlow

VoiceFlow is a free native macOS speech-to-text app. Speak naturally and turn your words into text for AI chats, messages, notes, and longer writing without typing everything manually.

## Download

Download the current macOS release:

https://github.com/LXXNDX-PXNDX/VoiceFlow/releases/tag/v1.2.4

## Features

- Native macOS app built with SwiftUI
- Local speech recognition using whisper.cpp
- No cloud dependency for transcription
- Runs on Apple Silicon
- macOS 14.0+ deployment target

## Requirements

- macOS 14.0 or later
- Apple Silicon (ARM64)
- Xcode 16.0
- Swift 5.9

## Project structure

```text
VoiceFlow/
├── VoiceFlow/           # Main app source code
├── whisper.cpp/         # Whisper C++ library
├── VoiceFlow.xcodeproj/ # Xcode project
├── project.yml          # XcodeGen project specification
└── icon_1024.png        # App icon
```

## Build

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```bash
xcodegen generate
open VoiceFlow.xcodeproj
```

## License

All rights reserved.

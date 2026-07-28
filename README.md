# VoiceFlow

VoiceFlow is a free native macOS speech-to-text app. Speak naturally and turn your words into text for AI chats, messages, notes, and longer writing without typing everything manually.

## Download

Download the latest macOS release:

https://github.com/LXXNDX-PXNDX/VoiceFlow/releases/latest

## Features

- Native macOS app built with SwiftUI
- Local speech recognition using whisper.cpp
- No cloud dependency for transcription
- Runs on Apple Silicon
- macOS 14.0+ deployment target
- Free and open source under the MIT License

## Landing page

The production landing page lives in [`website/`](website/). It is built with React, TypeScript, Tailwind CSS, and Framer Motion, and automatically deploys through GitHub Actions.

```bash
cd website
npm install
npm run dev
```

Production checks:

```bash
npm run lint
npm run build
```

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
├── website/             # Public landing page
└── icon_1024.png        # App icon
```

## Build the macOS app

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```bash
xcodegen generate
open VoiceFlow.xcodeproj
```

## License

MIT — see [LICENSE](LICENSE).

# VoiceFlow

VoiceFlow is a free macOS speech-to-text app. Speak naturally and turn your words into text for AI chats, messages, notes, and longer writing without typing everything manually.

The repository contains both the native macOS app and its public landing page.

## macOS app

The native app is built with SwiftUI and powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) for local speech recognition.

### Features

- Native macOS app built with SwiftUI
- Local speech recognition using whisper.cpp
- Runs on Apple Silicon
- macOS 14.0+ deployment target

### Requirements

- macOS 14.0 or later
- Apple Silicon (ARM64)
- Xcode 16.0
- Swift 5.9

### App structure

```text
VoiceFlow/
├── VoiceFlow/           # Main app source code
├── whisper.cpp/         # Whisper C++ library
├── VoiceFlow.xcodeproj/ # Xcode project
├── project.yml          # XcodeGen project specification
└── icon_1024.png        # App icon
```

### Build the app

```bash
xcodegen generate
open VoiceFlow.xcodeproj
```

## Landing page

The landing page is built with:

- React
- Vite
- Tailwind CSS
- Framer Motion

### Run locally

```bash
npm install
npm run dev
```

### Production build

```bash
npm run build
```

### Download link

The website download buttons point to the latest GitHub release asset:

```text
https://github.com/LXXNDX-PXNDX/VoiceFlow/releases/latest/download/VoiceFlow.dmg
```

Upload the app to a GitHub release with the exact filename `VoiceFlow.dmg`. The landing page will then automatically download the newest release.

### Deploy the website

Import the repository into Vercel with these settings:

- Framework preset: Vite
- Build command: `npm run build`
- Output directory: `dist`

## License

All rights reserved.

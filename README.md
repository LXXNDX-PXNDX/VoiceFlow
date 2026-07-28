# VoiceFlow

VoiceFlow is a free native macOS speech-to-text app. Hold a global key, speak naturally, and the finished text is inserted into the active app. Transcription runs locally with whisper.cpp—no account and no audio upload.

## Download

Download the latest macOS release:

https://github.com/LXXNDX-PXNDX/VoiceFlow/releases/latest

## VoiceFlow 1.1

The 1.1 update focuses on latency, recognition and a simpler native interface:

- Apple Silicon GPU inference with Metal, Accelerate and Flash Attention
- Leading and trailing silence removed before inference
- Lower-allocation microphone pipeline with responsive 30 fps level updates
- System-language resolution for faster and more reliable short dictation
- Three decoder profiles: Automatic, Instant and Precise
- Optional local vocabulary hints for names, brands and specialist terms
- Conservative smart formatting for spacing, punctuation and sentence starts
- Real processing-speed feedback in the app
- Redesigned focused dictation screen and smaller floating recording indicator

## Requirements

- macOS 14.0 or later
- Apple Silicon (ARM64)
- Xcode 16.0 or later
- CMake and Git for building the local whisper.cpp libraries

## Build the macOS app

The repository intentionally does not commit generated static libraries. Build the pinned whisper.cpp v1.8.6 libraries first, then open the Xcode project:

```bash
bash scripts/build-whisper-libs.sh
open VoiceFlow.xcodeproj
```

The script creates these ignored build artifacts in `VoiceFlow/Libs/`:

- `libwhisper.a`
- `libggml.a`
- `libggml-base.a`
- `libggml-cpu.a`
- `libggml-metal.a`
- `libggml-blas.a`

The project uses XcodeGen when the project file needs to be regenerated:

```bash
brew install xcodegen
xcodegen generate
```

A native macOS GitHub Actions workflow builds the same pinned libraries and compiles the full app without code signing on every relevant pull request.

## Project structure

```text
VoiceFlow/
├── VoiceFlow/             # SwiftUI app, audio and whisper bridge
├── VoiceFlow.xcodeproj/   # Xcode project
├── project.yml            # XcodeGen project specification
├── scripts/               # Reproducible native dependency builds
├── website/               # Public React landing page
└── .github/workflows/     # Website and native macOS CI
```

## Privacy

Audio samples, custom vocabulary and transcripts remain on the Mac. VoiceFlow uses the network only to download a selected speech model when it is not already installed.

## License

MIT — see [LICENSE](LICENSE).

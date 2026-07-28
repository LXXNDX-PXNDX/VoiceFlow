import AVFoundation

/// Captures microphone audio and hands back 16 kHz mono float samples for whisper.cpp.
final class AudioRecorder {

    /// Normalised 0…1 input level, delivered on the main queue while recording.
    var onLevel: ((Float) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let targetSampleRate: Double = 16_000
    private let bufferLock = NSLock()

    private var audioBuffer = [Float]()
    private var isRunning = false
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    var isRecording: Bool { isRunning }

    @discardableResult
    func startRecording() -> Bool {
        guard !isRunning else { return true }

        bufferLock.lock()
        audioBuffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        // A previous failed start can leave a tap installed; removing an absent tap is harmless.
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let inputFormat = inputNode.outputFormat(forBus: 0)
        NSLog("[Audio] Input format: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) ch")

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            NSLog("[Audio] ERROR: no usable microphone input")
            return false
        }

        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: targetSampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            NSLog("[Audio] ERROR: could not build 16 kHz target format")
            return false
        }
        targetFormat = target

        let needsConversion = abs(inputFormat.sampleRate - targetSampleRate) > 1.0
            || inputFormat.channelCount != 1
            || inputFormat.commonFormat != .pcmFormatFloat32

        if needsConversion {
            guard let conv = AVAudioConverter(from: inputFormat, to: target) else {
                NSLog("[Audio] ERROR: could not create converter from \(inputFormat)")
                return false
            }
            converter = conv
            NSLog("[Audio] Converting \(inputFormat.sampleRate) Hz / \(inputFormat.channelCount) ch → 16 kHz mono")
        } else {
            converter = nil
            NSLog("[Audio] Native 16 kHz mono input, no conversion needed")
        }

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer, inputFormat: inputFormat)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRunning = true
            NSLog("[Audio] Recording started")
            return true
        } catch {
            inputNode.removeTap(onBus: 0)
            NSLog("[Audio] ERROR starting engine: \(error.localizedDescription)")
            return false
        }
    }

    private func handle(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard let target = targetFormat else { return }

        let samples: [Float]
        if let converter = converter {
            let ratio = targetSampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
            guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

            // The converter may pull more than once per call. Feeding it the same buffer
            // repeatedly duplicates audio, so hand it over exactly once and then report
            // that the input ran dry.
            var consumed = false
            var error: NSError?
            let status = converter.convert(to: converted, error: &error) { _, outStatus in
                if consumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, let data = converted.floatChannelData?[0] else {
                if let error = error { NSLog("[Audio] Conversion error: \(error.localizedDescription)") }
                return
            }
            samples = Array(UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
        } else {
            guard let data = buffer.floatChannelData?[0] else { return }
            samples = Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
        }

        guard !samples.isEmpty else { return }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        publishLevel(for: samples)
    }

    private func publishLevel(for samples: [Float]) {
        guard onLevel != nil else { return }

        var sum: Float = 0
        for sample in samples { sum += sample * sample }
        let rms = sqrt(sum / Float(samples.count))

        // Map roughly -50 dBFS … 0 dBFS onto 0 … 1 so quiet speech still moves the meter.
        let db = 20 * log10(max(rms, 1e-7))
        let level = min(max((db + 50) / 50, 0), 1)

        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }
    }

    /// Stops capture and returns everything recorded as 16 kHz mono samples.
    @discardableResult
    func stopRecording() -> [Float] {
        guard isRunning else { return [] }
        isRunning = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        converter = nil

        bufferLock.lock()
        let result = audioBuffer
        audioBuffer.removeAll(keepingCapacity: false)
        bufferLock.unlock()

        let seconds = Double(result.count) / targetSampleRate
        NSLog("[Audio] Stopped. \(result.count) samples (\(String(format: "%.2f", seconds)) s)")
        return result
    }

    /// Throws away whatever has been captured so far without transcribing it.
    func cancel() {
        guard isRunning else { return }
        _ = stopRecording()
    }
}

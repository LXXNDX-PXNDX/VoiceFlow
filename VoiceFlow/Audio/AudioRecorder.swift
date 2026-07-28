import AVFoundation

/// Captures microphone audio and hands back clean 16 kHz mono float samples for whisper.cpp.
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
    private var lastLevelDelivery: CFAbsoluteTime = 0
    private var smoothedLevel: Float = 0

    var isRecording: Bool { isRunning }

    @discardableResult
    func startRecording() -> Bool {
        guard !isRunning else { return true }

        bufferLock.lock()
        audioBuffer.removeAll(keepingCapacity: true)
        // Reserve enough for the maximum recording length once. This prevents repeated
        // allocations and copies while audio is arriving on the realtime callback.
        audioBuffer.reserveCapacity(Int(targetSampleRate * AppState.maxRecordingSeconds))
        bufferLock.unlock()

        lastLevelDelivery = 0
        smoothedLevel = 0

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

        // 1024 frames keeps the waveform responsive without flooding the main actor.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
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

        if let converter {
            let ratio = targetSampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 64
            guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }

            // The converter may pull more than once per call. Feeding it the same buffer
            // repeatedly duplicates audio, so hand it over exactly once.
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

            guard status != .error,
                  converted.frameLength > 0,
                  let data = converted.floatChannelData?[0] else {
                if let error { NSLog("[Audio] Conversion error: \(error.localizedDescription)") }
                return
            }

            append(UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
        } else {
            guard buffer.frameLength > 0, let data = buffer.floatChannelData?[0] else { return }
            append(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
        }
    }

    /// Copies each audio block exactly once into the final recording buffer. The previous
    /// implementation first materialised a temporary Array, doubling callback allocations.
    private func append(_ samples: UnsafeBufferPointer<Float>) {
        guard !samples.isEmpty else { return }

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        publishLevel(for: samples)
    }

    private func publishLevel(for samples: UnsafeBufferPointer<Float>) {
        guard onLevel != nil else { return }

        // Cap visual updates at ~30 fps; inference audio is never dropped.
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastLevelDelivery >= 1.0 / 30.0 else { return }
        lastLevelDelivery = now

        var sum: Float = 0
        for sample in samples { sum += sample * sample }
        let rms = sqrt(sum / Float(samples.count))

        // Map roughly -52 dBFS … 0 dBFS onto 0 … 1 and smooth small buffer jumps.
        let db = 20 * log10(max(rms, 1e-7))
        let rawLevel = min(max((db + 52) / 52, 0), 1)
        smoothedLevel = smoothedLevel * 0.62 + rawLevel * 0.38
        let level = smoothedLevel

        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }
    }

    /// Stops capture and returns voice-focused 16 kHz mono samples.
    @discardableResult
    func stopRecording() -> [Float] {
        guard isRunning else { return [] }
        isRunning = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        converter = nil

        bufferLock.lock()
        let captured = audioBuffer
        audioBuffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        let prepared = Self.prepareForTranscription(captured)
        let rawSeconds = Double(captured.count) / targetSampleRate
        let preparedSeconds = Double(prepared.count) / targetSampleRate
        NSLog("[Audio] Stopped. \(String(format: "%.2f", rawSeconds)) s raw → \(String(format: "%.2f", preparedSeconds)) s voice")
        return prepared
    }

    /// Removes leading/trailing room noise, DC offset and conservatively boosts quiet speech.
    /// Less silence means fewer Whisper encoder frames and noticeably lower end-to-end latency.
    private static func prepareForTranscription(_ input: [Float]) -> [Float] {
        let sampleRate = 16_000
        let minimumUsefulSamples = 6_400
        guard input.count > minimumUsefulSamples else { return input }

        let frameSize = 320       // 20 ms
        let hopSize = 160         // 10 ms
        var energies = [Float]()
        energies.reserveCapacity(input.count / hopSize)

        var offset = 0
        while offset + frameSize <= input.count {
            var sum: Float = 0
            for index in offset..<(offset + frameSize) {
                let value = input[index]
                sum += value * value
            }
            energies.append(sqrt(sum / Float(frameSize)))
            offset += hopSize
        }

        guard !energies.isEmpty else { return input }
        let sorted = energies.sorted()
        let noiseFloor = sorted[min(sorted.count - 1, sorted.count / 5)]
        let speechThreshold = max(0.004, noiseFloor * 2.8)

        guard let firstActive = energies.firstIndex(where: { $0 >= speechThreshold }),
              let lastActive = energies.lastIndex(where: { $0 >= speechThreshold }) else {
            return input
        }

        let padding = 2_400 // 150 ms on both sides, preserving initial/final consonants.
        let start = max(0, firstActive * hopSize - padding)
        let end = min(input.count, lastActive * hopSize + frameSize + padding)
        guard end - start >= minimumUsefulSamples else { return input }

        var output = Array(input[start..<end])

        var mean: Float = 0
        for sample in output { mean += sample }
        mean /= Float(output.count)

        var peak: Float = 0
        for index in output.indices {
            output[index] -= mean
            peak = max(peak, abs(output[index]))
        }

        // Only boost genuinely quiet recordings and never apply enough gain to clip.
        if peak > 0.008, peak < 0.28 {
            let gain = min(3.0, 0.28 / peak)
            for index in output.indices { output[index] *= gain }
        }

        return output
    }

    /// Throws away whatever has been captured so far without transcribing it.
    func cancel() {
        guard isRunning else { return }
        _ = stopRecording()
    }
}

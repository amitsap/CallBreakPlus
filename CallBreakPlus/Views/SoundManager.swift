import AVFoundation
import os

private let logger = Logger(subsystem: "edu.amitsapkota.callbreakplus", category: "audio")

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var activePlayers: [AVAudioPlayer] = []
    private var soundData: [SoundEffect: Data] = [:]
    private var sessionActivated = false
    var isEnabled = true

    enum SoundEffect: String, CaseIterable {
        case cardDeal
        case cardPlay
        case cardSlide
        case trickWin
        case bidPlace
        case roundComplete
        case gameWin
        case gameLose
    }

    private init() {
        configureAudioSession()
        generateSounds()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            logger.warning("Failed to configure audio session category: \(error.localizedDescription)")
        }
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled, let data = soundData[effect] else { return }
        if !sessionActivated {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                logger.warning("Failed to activate audio session: \(error.localizedDescription)")
            }
            sessionActivated = true
        }
        activePlayers.removeAll { !$0.isPlaying }
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.prepareToPlay()
        player.volume = 1.0
        player.play()
        activePlayers.append(player)
    }

    // MARK: - Sound generation

    private func generateSounds() {
        soundData[.cardDeal] = cardFlickSound(duration: 0.06, brightness: 0.8, volume: 0.5)
        soundData[.cardPlay] = cardFlickSound(duration: 0.09, brightness: 0.6, volume: 0.6)
        soundData[.cardSlide] = cardSlideSound(duration: 0.10, volume: 0.45)
        soundData[.trickWin] = makeChordData(frequencies: [523, 659, 784], duration: 0.3, volume: 0.5)
        soundData[.bidPlace] = cardFlickSound(duration: 0.05, brightness: 0.9, volume: 0.4)
        soundData[.roundComplete] = makeChordData(frequencies: [523, 659, 784, 1047], duration: 0.45, volume: 0.45)
        soundData[.gameWin] = makeArpeggioData(frequencies: [523, 659, 784, 1047], noteDuration: 0.15, volume: 0.5)
        soundData[.gameLose] = makeChordData(frequencies: [262, 311, 370], duration: 0.5, volume: 0.4)
    }

    private func cardFlickSound(duration: Double, brightness: Double, volume: Float) -> Data? {
        let sampleRate = 44100.0
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        var state: UInt64 = 12345

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let attack = min(t / 0.002, 1.0)
            let decay = pow(max(0, 1.0 - t / duration), 2.0)
            let envelope = Float(attack * decay)

            state = state &* 6364136223846793005 &+ 1442695040888963407
            let white = Float(Int64(bitPattern: state) >> 33) / Float(Int32.max)

            let cutoff = Float(brightness) * envelope
            let filtered = white * cutoff

            samples[i] = filtered * envelope * volume
        }

        return wavData(from: samples, sampleRate: sampleRate)
    }

    private func cardSlideSound(duration: Double, volume: Float) -> Data? {
        let sampleRate = 44100.0
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        var state: UInt64 = 67890
        var prev: Float = 0

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let envelope = Float(sin(.pi * t / duration)) * 0.8

            state = state &* 6364136223846793005 &+ 1442695040888963407
            let white = Float(Int64(bitPattern: state) >> 33) / Float(Int32.max)

            let filtered = prev * 0.7 + white * 0.3
            prev = filtered

            samples[i] = filtered * envelope * volume
        }

        return wavData(from: samples, sampleRate: sampleRate)
    }

    private func makeChordData(frequencies: [Double], duration: Double, volume: Float) -> Data? {
        let sampleRate = 44100.0
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        let amp = volume / Float(frequencies.count)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, min(t / 0.008, pow((duration - t) / (duration * 0.4), 1.5)))
            var sample: Float = 0
            for freq in frequencies {
                sample += Float(sin(2.0 * .pi * freq * t) * envelope) * amp
            }
            samples[i] = sample
        }

        return wavData(from: samples, sampleRate: sampleRate)
    }

    private func makeArpeggioData(frequencies: [Double], noteDuration: Double, volume: Float) -> Data? {
        let sampleRate = 44100.0
        let totalDuration = noteDuration * Double(frequencies.count) + 0.15
        let sampleCount = Int(sampleRate * totalDuration)
        var samples = [Float](repeating: 0, count: sampleCount)

        for (noteIndex, freq) in frequencies.enumerated() {
            let startSample = Int(Double(noteIndex) * noteDuration * sampleRate)
            let noteSamples = Int(noteDuration * sampleRate * 1.5)

            for i in 0..<noteSamples {
                let idx = startSample + i
                guard idx < sampleCount else { break }
                let t = Double(i) / sampleRate
                let env = min(1.0, min(t / 0.003, pow((noteDuration * 1.5 - t) / (noteDuration * 0.6), 1.5)))
                samples[idx] += Float(sin(2.0 * .pi * freq * t) * env) * volume
            }
        }

        return wavData(from: samples, sampleRate: sampleRate)
    }

    private func wavData(from samples: [Float], sampleRate: Double) -> Data? {
        let bitsPerSample: UInt16 = 16
        let numChannels: UInt16 = 1
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize

        var data = Data()

        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func appendU32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func appendU16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF"); appendU32(fileSize); append("WAVE"); append("fmt ")
        appendU32(16); appendU16(1); appendU16(numChannels)
        appendU32(UInt32(sampleRate)); appendU32(byteRate); appendU16(blockAlign); appendU16(bitsPerSample)
        append("data"); appendU32(dataSize)

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: int16.littleEndian) { data.append(contentsOf: $0) }
        }

        return data
    }
}

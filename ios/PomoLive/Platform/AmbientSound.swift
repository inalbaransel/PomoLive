import AVFoundation
import Observation
import SwiftUI

/// A background soundscape, synthesised live so nothing needs to be shipped or licensed.
enum AmbientSound: String, CaseIterable, Identifiable {
    case rain, waves, fireplace, brown, pink, white

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .rain: "Yağmur"
        case .waves: "Dalgalar"
        case .fireplace: "Şömine"
        case .brown: "Derin Uğultu"
        case .pink: "Pembe Gürültü"
        case .white: "Beyaz Gürültü"
        }
    }

    var symbol: String {
        switch self {
        case .rain: "cloud.rain.fill"
        case .waves: "water.waves"
        case .fireplace: "flame.fill"
        case .brown: "wind"
        case .pink: "waveform"
        case .white: "waveform.path"
        }
    }

    var color: Color {
        switch self {
        case .rain: .blue
        case .waves: .teal
        case .fireplace: .orange
        case .brown: .brown
        case .pink: .pink
        case .white: .gray
        }
    }

    /// The sound that suits a room's scenery.
    static func suggested(for theme: RoomTheme) -> AmbientSound {
        switch theme {
        case .classic, .space: .brown
        case .coffeeShop: .fireplace
        case .forest: .rain
        case .beach: .waves
        }
    }
}

/// Plays one ambient sound at a time and keeps going while the phone is locked.
/// Sounds fade in and out so starting, stopping and switching never click.
@MainActor
@Observable
final class AmbientPlayer {
    private(set) var current: AmbientSound?
    var volume: Float = 0.6 {
        didSet { engine.mainMixerNode.outputVolume = volume }
    }

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var source: AVAudioSourceNode?
    @ObservationIgnored private let state = SynthState()

    func toggle(_ sound: AmbientSound) {
        current == sound ? stop() : play(sound)
    }

    func play(_ sound: AmbientSound) {
        current = sound
        state.switchTo(sound)
        guard source == nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let format = engine.outputNode.inputFormat(forBus: 0)
            let sampleRate = Float(format.sampleRate)
            let node = Self.makeSource(state, sampleRate: sampleRate)
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 2))
            engine.mainMixerNode.outputVolume = volume
            try engine.start()
            source = node
        } catch {
            current = nil
        }
    }

    func stop() {
        current = nil
        state.fadeOut { [weak self] in
            Task { @MainActor in self?.tearDown() }
        }
    }

    /// Built outside the main actor: the render block runs on the real-time audio thread.
    private nonisolated static func makeSource(_ synth: SynthState, sampleRate: Float) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            synth.render(frameCount: Int(frameCount), sampleRate: sampleRate, buffers: UnsafeMutableAudioBufferListPointer(bufferList))
            return noErr
        }
    }

    private func tearDown() {
        guard current == nil, let source else { return }
        engine.stop()
        engine.detach(source)
        self.source = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// The real-time synthesiser. Lives off the main actor; the audio thread reads it directly.
/// Every sound is shaped noise: low-pass filtering turns white noise pink and brown, slow
/// envelopes make waves, random bursts make raindrops and crackles.
private final class SynthState: @unchecked Sendable {
    private let lock = NSLock()
    private var sound: AmbientSound = .brown
    private var target: Float = 0
    private var gain: Float = 0
    private var onSilent: (@Sendable () -> Void)?

    private var seed: UInt32 = 0x9E37_79B9
    private var brown: Float = 0
    private var pink: (Float, Float, Float) = (0, 0, 0)
    private var low: Float = 0
    private var phase: Float = 0
    private var burst: Float = 0
    private var burstDecay: Float = 0
    private var lastSample: Float = 0

    func switchTo(_ next: AmbientSound) {
        lock.withLock {
            if gain < 0.01 { sound = next }
            pendingSound = next
            target = 1
            onSilent = nil
        }
    }

    private var pendingSound: AmbientSound?

    func fadeOut(then done: @escaping @Sendable () -> Void) {
        lock.withLock {
            target = 0
            pendingSound = nil
            onSilent = done
        }
    }

    func render(frameCount: Int, sampleRate: Float, buffers: UnsafeMutableAudioBufferListPointer) {
        lock.lock()
        defer { lock.unlock() }
        let fade: Float = 1 / (sampleRate * 0.6)
        var finished: (@Sendable () -> Void)?
        for frame in 0..<frameCount {
            // Cross-fade: dip to silence, swap the sound, come back up.
            if let pending = pendingSound, pending != sound {
                gain = max(0, gain - fade)
                if gain == 0 { sound = pending }
            } else if gain < target {
                gain = min(target, gain + fade)
            } else if gain > target {
                gain = max(target, gain - fade)
                if gain == 0, let done = onSilent {
                    finished = done
                    onSilent = nil
                }
            }
            let sample = next(sampleRate: sampleRate) * gain
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
            }
        }
        if let finished { DispatchQueue.main.async(execute: finished) }
    }

    private func white() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    private func next(sampleRate: Float) -> Float {
        let noise = white()
        brown = (brown + noise * 0.02) * 0.998
        pink.0 = 0.997 * pink.0 + noise * 0.029591
        pink.1 = 0.985 * pink.1 + noise * 0.032534
        pink.2 = 0.950 * pink.2 + noise * 0.048056
        let pinkNoise = (pink.0 + pink.1 + pink.2 + noise * 0.1848) * 0.9

        switch sound {
        case .white:
            return noise * 0.18
        case .pink:
            return pinkNoise * 0.45
        case .brown:
            return brown * 0.65
        case .waves:
            // A swell every ~9 s: brown noise breathing in and out.
            phase += 1 / (sampleRate * 9)
            if phase > 1 { phase -= 1 }
            let swell = 0.25 + 0.75 * pow(sin(phase * .pi), 2)
            low += (pinkNoise - low) * 0.08
            return (brown * 0.6 + low * 0.25) * swell
        case .rain:
            // A soft hiss of pink noise with scattered bright drops.
            if white() > 0.9993 { burst = 0.6 + white() * 0.3; burstDecay = 0.985 }
            burst *= burstDecay
            let drop = (noise - lastSample) * burst
            lastSample = noise
            low += (pinkNoise - low) * 0.35
            return low * 0.32 + drop * 0.25
        case .fireplace:
            // Low rumble with sharp crackles at random.
            if white() > 0.9996 { burst = 1; burstDecay = 0.93 + abs(white()) * 0.05 }
            burst *= burstDecay
            let crackle = noise * burst
            return brown * 0.45 + crackle * 0.3
        }
    }
}

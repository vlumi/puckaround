import AVFoundation
import Foundation
import PuckaroundCore

/// Procedural game audio — no audio assets, in the same spirit as the graphics.
/// One `AVAudioSourceNode` synthesizes short percussive envelopes triggered by
/// the sim's `GameEvent`s: a click on a mallet hit, a duller knock on a wall,
/// a two-note horn on a goal.
///
/// The render block runs on the audio thread; it reads pending triggers through
/// a lock and shapes them per-sample, so the tick loop can fire freely.
@MainActor
final class SoundEngine {
    /// A percussive voice: a decaying tone plus a noise transient. One struct
    /// per concurrent sound — a hit and a goal can ring at once.
    private struct Hit {
        var hz = 0.0
        var gain = 0.0
        var noise = 0.0
        var decay = 0.0
        var phase = 0.0
        var env = 0.0

        mutating func trigger(hz: Double, gain: Double, noise: Double, decay: Double) {
            self.hz = hz
            self.gain = gain
            self.noise = noise
            self.decay = decay
            env = 1
            phase = 0
        }

        mutating func sample(rate: Double, seed: inout UInt64) -> Double {
            guard env > 0.0005 else {
                env = 0
                return 0
            }
            phase += hz / rate
            phase -= phase.rounded(.down)
            let tone = sin(phase * 2 * .pi)
            let white = SoundEngine.noise(&seed)
            let value = (tone * (1 - noise) + white * noise) * env * gain
            env *= decay
            return value
        }
    }

    /// A queued trigger for one voice.
    private struct Trigger {
        var hz: Double
        var gain: Double
        var noise: Double
        var decay: Double
    }

    private final class State: @unchecked Sendable {
        private let lock = NSLock()
        // One slot per event kind, so simultaneous kinds don't clobber each
        // other; a second hit of the same kind restarts that slot, which reads
        // as a rally rather than a chord.
        private var pending: [Int: Trigger] = [:]

        func fire(slot: Int, _ trigger: Trigger) {
            lock.lock()
            pending[slot] = trigger
            lock.unlock()
        }

        func drain() -> [Int: Trigger] {
            lock.lock()
            defer {
                pending.removeAll(keepingCapacity: true)
                lock.unlock()
            }
            return pending
        }
    }

    private let engine = AVAudioEngine()
    private let state = State()
    private var running = false
    var enabled = true

    init() {}

    func start() {
        guard enabled, !running else { return }
        #if os(iOS)
        // Ambient: respects the silent switch, mixes with the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let format = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100
        let node = makeSourceNode(sampleRate: sampleRate)
        engine.attach(node)
        engine.connect(
            node, to: engine.mainMixerNode,
            format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        engine.mainMixerNode.outputVolume = 0.6
        running = (try? engine.start()) != nil
    }

    func stop() {
        guard running else { return }
        engine.stop()
        running = false
    }

    /// Fire the sounds for one tick's events.
    func play(_ events: [GameEvent]) {
        guard running else { return }
        for event in events {
            fire(event)
        }
    }

    private func fire(_ event: GameEvent) {
        switch event {
        case .malletHit(_, let speed):
            // A bright, short click; harder hits ring a touch higher and louder.
            let hard = min(1, speed / 260)
            state.fire(
                slot: 0,
                Trigger(hz: 320 + hard * 140, gain: 0.4 + hard * 0.4, noise: 0.5, decay: 0.9992))
        case .wallBounce(let speed):
            guard speed > 40 else { return }
            let hard = min(1, speed / 300)
            state.fire(
                slot: 1,
                Trigger(hz: 150 + hard * 60, gain: 0.25 + hard * 0.35, noise: 0.7, decay: 0.9988))
        case .puckHit(let speed):
            // Puck on puck: a dry clack, brighter than the boards but with none
            // of the mallet's ring.
            guard speed > 40 else { return }
            let hard = min(1, speed / 300)
            state.fire(
                slot: 1,
                Trigger(hz: 230 + hard * 80, gain: 0.2 + hard * 0.3, noise: 0.6, decay: 0.999))
        case .bumperHit(let speed):
            // A bumper's clang: brighter and rounder than the boards — pinball
            // brass, so racking points sounds like racking points.
            let hard = min(1, speed / 300)
            state.fire(
                slot: 1,
                Trigger(hz: 500 + hard * 180, gain: 0.3 + hard * 0.35, noise: 0.15, decay: 0.9992))
        case .brickBroken(let speed):
            // A brick going: a crunchy snap, more noise than tone — something
            // broke, nothing rang.
            let hard = min(1, speed / 300)
            state.fire(
                slot: 1,
                Trigger(hz: 360 + hard * 120, gain: 0.35 + hard * 0.3, noise: 0.75, decay: 0.9985))
        case .brickChipped(let speed):
            // A chip: the wall held — duller and lower than a break.
            let hard = min(1, speed / 300)
            state.fire(
                slot: 1,
                Trigger(hz: 230 + hard * 80, gain: 0.3 + hard * 0.25, noise: 0.8, decay: 0.9982))
        default:
            fireFanfare(event)
        }
    }

    /// The ceremonial family — goals, wins, and the GO — split from the
    /// percussive hits to keep each switch under the complexity limit.
    private func fireFanfare(_ event: GameEvent) {
        switch event {
        case .goal:
            state.fire(slot: 2, Trigger(hz: 523, gain: 0.7, noise: 0.05, decay: 0.99985))
        case .gameWon:
            state.fire(slot: 3, Trigger(hz: 659, gain: 0.8, noise: 0.03, decay: 0.99992))
        case .matchOver:
            // The match: higher and longer than a game — the bigger flourish.
            state.fire(slot: 3, Trigger(hz: 784, gain: 0.9, noise: 0.03, decay: 0.99995))
        case .faceoffCleared:
            // The "GO": a bright, punchy whistle-crack as the field bursts.
            state.fire(slot: 3, Trigger(hz: 880, gain: 0.9, noise: 0.25, decay: 0.9994))
        case .puckBeamed:
            // The rescue beam: a soft high shimmer — out, and back in play.
            state.fire(slot: 2, Trigger(hz: 980, gain: 0.3, noise: 0.1, decay: 0.9994))
        default:
            break
        }
    }

    /// One xorshift noise sample in -1…1. Advances `seed` in place.
    private nonisolated static func noise(_ seed: inout UInt64) -> Double {
        seed ^= seed << 13
        seed ^= seed >> 7
        seed ^= seed << 17
        return Double(Int64(bitPattern: seed % 2000) - 1000) / 1000
    }

    private func makeSourceNode(sampleRate: Double) -> AVAudioSourceNode {
        let state = self.state
        var voices = [Hit](repeating: Hit(), count: 4)
        var seed: UInt64 = 0x9E37_79B9
        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            for (slot, t) in state.drain() where slot < voices.count {
                voices[slot].trigger(hz: t.hz, gain: t.gain, noise: t.noise, decay: t.decay)
            }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            for frame in 0..<Int(frameCount) {
                var sample = 0.0
                for index in voices.indices {
                    sample += voices[index].sample(rate: sampleRate, seed: &seed)
                }
                // Soft limit rather than a hard clamp, so a goal landing on a
                // rally gets louder instead of clipping to square-wave buzz.
                out[frame] = Float(tanh(sample))
            }
            return noErr
        }
    }
}

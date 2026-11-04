//
//  Sound.swift
//  CRS Soccer Field
//
//  Every sound in the game is made in code when the app starts: the crowd's
//  murmur and cheer, the kick, the thump of the ball or a tackle on a body or
//  legs, the referee's whistle, the swish of the net and the ping of the post.
//  It uses the "ambient" audio setting, so the phone's silent switch mutes it
//  and it never stops music a parent is playing.
//

import Foundation
import AVFoundation

final class Sound {
    static let shared = Sound()

    enum Effect: CaseIterable { case kick, thud, whistle, longWhistle, cheer, net, post, clap }

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    private let sampleRate: Double = 44_100
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var pools: [Effect: [AVAudioPlayerNode]] = [:]
    private var next: [Effect: Int] = [:]
    private let crowd = AVAudioPlayerNode()
    private var crowdBuffer: AVAudioPCMBuffer?
    private var running = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        for effect in Effect.allCases {
            buffers[effect] = make(effect)
            let count = (effect == .kick || effect == .thud) ? 4 : 2
            var nodes: [AVAudioPlayerNode] = []
            for _ in 0..<count {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: format)
                nodes.append(node)
            }
            pools[effect] = nodes
            next[effect] = 0
        }
        engine.attach(crowd)
        engine.connect(crowd, to: engine.mainMixerNode, format: format)
        crowdBuffer = makeCrowd()
    }

    func start() {
        guard !running else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.prepare()
        do { try engine.start() } catch { return }
        running = true
        if let crowdBuffer {
            crowd.volume = 0.22
            crowd.scheduleBuffer(crowdBuffer, at: nil, options: .loops)
            crowd.play()
        }
    }

    func stop() {
        guard running else { return }
        crowd.stop()
        for nodes in pools.values { for n in nodes { n.stop() } }
        engine.stop()
        running = false
    }

    /// How loud the crowd murmurs, 0 to 1.
    func crowdLevel(_ level: Float) {
        crowd.volume = level
    }

    func play(_ effect: Effect, volume: Float = 1) {
        guard running, let buffer = buffers[effect], let nodes = pools[effect], !nodes.isEmpty else { return }
        let index = (next[effect] ?? 0) % nodes.count
        next[effect] = index + 1
        let node = nodes[index]
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    // MARK: Making the sounds

    private func buffer(seconds: Double, _ sample: (Double, Int) -> Float) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = count
        for i in 0..<Int(count) {
            channel[i] = sample(Double(i) / sampleRate, i)
        }
        return buffer
    }

    private func make(_ effect: Effect) -> AVAudioPCMBuffer? {
        let twoPi = 2.0 * Double.pi
        let rate = sampleRate
        switch effect {
        case .kick:
            // A short thump that drops in pitch, with a little click of boot on ball.
            var phase = 0.0
            return buffer(seconds: 0.14) { t, _ in
                let drop: Double = exp(-t * 40.0)
                let frequency: Double = 70.0 + 110.0 * drop
                phase += twoPi * frequency / rate
                let body: Double = sin(phase) * exp(-t * 28.0)
                let click: Double = t < 0.006 ? Double.random(in: -1.0...1.0) * 0.35 : 0.0
                return Float((body + click) * 0.9)
            }
        case .thud:
            // Softer and lower: the ball or a tackle bumping into a body or legs.
            var phase = 0.0
            var smooth = 0.0
            return buffer(seconds: 0.16) { t, _ in
                phase += twoPi * 85.0 / rate
                smooth += 0.12 * (Double.random(in: -1.0...1.0) - smooth)
                let tone: Double = sin(phase) * 0.8 + smooth * 1.2
                return Float(tone * exp(-t * 24.0) * 0.85)
            }
        case .whistle, .longWhistle:
            // A pea whistle: a high note with a fast trill.
            let length: Double = effect == .whistle ? 0.38 : 0.95
            var phase = 0.0
            return buffer(seconds: length) { t, _ in
                let trill: Double = sin(twoPi * 28.0 * t)
                let frequency: Double = 2900.0 + 140.0 * trill
                phase += twoPi * frequency / rate
                let attack: Double = min(1.0, t / 0.012)
                let release: Double = min(1.0, (length - t) / 0.05)
                return Float(sin(phase) * attack * release * 0.32)
            }
        case .net:
            // A swish: bright noise that fades quickly.
            var smooth = 0.0
            return buffer(seconds: 0.35) { t, _ in
                let noise: Double = Double.random(in: -1.0...1.0)
                smooth += 0.3 * (noise - smooth)
                return Float((noise - smooth) * exp(-t * 9.0) * 0.6)
            }
        case .clap:
            // Two hands meeting: a sharp, bright snap.
            var smooth = 0.0
            return buffer(seconds: 0.12) { t, _ in
                let noise: Double = Double.random(in: -1.0...1.0)
                smooth += 0.5 * (noise - smooth)
                let snap: Double = (noise - smooth * 0.5) * exp(-t * 45.0)
                return Float(snap * 0.7)
            }
        case .post:
            // A metal ping.
            return buffer(seconds: 0.5) { t, _ in
                let low: Double = sin(twoPi * 1250.0 * t) * 0.6
                let high: Double = sin(twoPi * 2610.0 * t) * 0.3
                return Float((low + high) * exp(-t * 9.0) * 0.45)
            }
        case .cheer:
            // A roar that swells and fades, with a flutter like many voices.
            let length = 3.2
            var smooth = 0.0
            var smoother = 0.0
            return buffer(seconds: length) { t, _ in
                smooth += 0.22 * (Double.random(in: -1.0...1.0) - smooth)
                smoother += 0.05 * (smooth - smoother)
                let swell: Double = min(1.0, t / 0.35) * min(1.0, (length - t) / 1.2)
                let wobble1: Double = 0.25 * sin(twoPi * 6.5 * t)
                let wobble2: Double = 0.15 * sin(twoPi * 11.0 * t)
                let flutter: Double = 1.0 + wobble1 + wobble2
                let voice: Double = smooth * 1.6 - smoother * 0.6
                return Float(voice * swell * flutter * 0.75)
            }
        }
    }

    /// A seamless crowd murmur that loops for the whole match.
    private func makeCrowd() -> AVAudioPCMBuffer? {
        let twoPi = 2.0 * Double.pi
        var smooth = 0.0
        let length = 4.0
        return buffer(seconds: length) { t, _ in
            smooth += 0.07 * (Double.random(in: -1.0...1.0) - smooth)
            let edge: Double = min(1.0, t / 0.05) * min(1.0, (length - t) / 0.05)
            let sway: Double = 1.0 + 0.12 * sin(twoPi * 0.5 * t)
            let level: Double = 0.85 + 0.15 * edge
            return Float(smooth * 2.2 * sway * level)
        }
    }
}

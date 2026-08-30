import Foundation
import PuckaroundCore

#if os(iOS)
import UIKit
#endif

/// Taps from the sim's own `GameEvent` stream — the part of a hit you feel.
/// iOS only; a no-op elsewhere so the macOS test build still links.
///
/// One engine per device is the whole design constraint: the device buzzes for
/// everyone at the table at once, so a tap is the *event*, not a given player's
/// experience of it. `prepare()` before a game keeps the first hit from lagging
/// while Taptic spins up.
@MainActor
public final class Haptics {
    #if os(iOS)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notice = UINotificationFeedbackGenerator()
    #endif

    public var enabled = true

    public init() {}

    public func prepare() {
        #if os(iOS)
        soft.prepare()
        light.prepare()
        rigid.prepare()
        #endif
    }

    public func play(_ events: [GameEvent]) {
        guard enabled else { return }
        #if os(iOS)
        for event in events {
            switch event {
            case .malletHit(_, let speed):
                // A hit's weight is its speed: a nudge stays soft, a slap is rigid.
                rigid.impactOccurred(intensity: intensity(forSpeed: speed, fast: 260))
            case .wallBounce(let speed):
                // Only bounces you'd feel — a slow drift into the boards is silent.
                if speed > 40 {
                    light.impactOccurred(intensity: intensity(forSpeed: speed, fast: 300) * 0.7)
                }
            case .goal:
                soft.impactOccurred(intensity: 1)
            case .gameWon:
                soft.impactOccurred(intensity: 1)
            case .matchOver:
                notice.notificationOccurred(.success)
            case .faceoffCleared:
                // The "GO": a firm pop as the force field bursts and play begins.
                rigid.impactOccurred(intensity: 1)
            }
        }
        #endif
    }

    /// 0.35…1 over 0…`fast` world units/s, so even a gentle touch is felt and a
    /// hard hit tops out rather than clipping.
    private func intensity(forSpeed speed: Double, fast: Double) -> Double {
        min(1, 0.35 + speed / fast * 0.65)
    }
}

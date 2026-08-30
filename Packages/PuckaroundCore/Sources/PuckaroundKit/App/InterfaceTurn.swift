import SwiftUI

#if os(iOS)
import UIKit
#endif

/// How far the board is turned so it follows the phone into every orientation —
/// magenta stays on the physical-bottom edge whichever way you hold it, including
/// upside down. Degrees clockwise; 0 in normal portrait. Read from the physical
/// device, so it catches upside-down portrait even though the interface refuses
/// to rotate there; a flat or unknown device falls back to the interface, so
/// laying the phone down mid-game doesn't snap the board around. iOS-only; 0 on
/// macOS (where `swift test` builds the Kit).
enum InterfaceTurn {
    static var degrees: Double {
        #if os(iOS)
        switch UIDevice.current.orientation {
        case .landscapeLeft: return -90
        case .landscapeRight: return 90
        case .portraitUpsideDown: return 180
        case .portrait: return 0
        default: return interfaceDegrees
        }
        #else
        return 0
        #endif
    }

    #if os(iOS)
    /// The turn implied by the interface alone — the fallback when the device
    /// is flat. (Interface landscapeLeft is device landscapeRight; the two
    /// enums name the same physical hold from opposite ends.)
    private static var interfaceDegrees: Double {
        let orientation =
            UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
        switch orientation {
        case .landscapeLeft: return 90
        case .landscapeRight: return -90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }
    #endif
}

extension View {
    /// Runs `act` whenever the physical device orientation changes, so the board
    /// can re-place itself — including the flips (left↔right, up↔down) that don't
    /// change the view's size and so escape a size-change hook. Inert off iOS.
    func onDeviceOrientationChange(_ act: @escaping () -> Void) -> some View {
        #if os(iOS)
        return
            onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIDevice.orientationDidChangeNotification)
            ) { _ in act() }
        #else
        return self
        #endif
    }
}

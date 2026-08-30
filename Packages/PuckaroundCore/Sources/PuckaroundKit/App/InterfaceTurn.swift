import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Which way the interface has rotated into landscape, so the board can turn the
/// same way the phone did — keeping magenta on the physical-bottom edge whichever
/// way you rotate. Portrait returns `true` (unused there). iOS-only; on macoS
/// (where `swift test` builds the Kit) it's a constant.
enum InterfaceTurn {
    static var clockwise: Bool {
        #if os(iOS)
        let orientation =
            UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .portrait
        // landscapeRight: the home edge is on the right, so the board turns
        // clockwise to keep its bottom (magenta) on the physical bottom;
        // landscapeLeft is the mirror.
        return orientation != .landscapeLeft
        #else
        return true
        #endif
    }
}

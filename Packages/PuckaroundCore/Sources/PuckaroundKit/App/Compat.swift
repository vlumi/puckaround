import SwiftUI

extension View {
    /// `onChange` for the iOS-16 floor without the macOS-14 deprecation
    /// warning: neither overload is clean on both platforms, so pick per OS.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V, perform action: @escaping (V) -> Void
    ) -> some View {
        if #available(iOS 17, macOS 14, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value) { newValue in action(newValue) }
        }
    }

    func statusBarHiddenIfAvailable() -> some View {
        #if os(iOS)
        return statusBarHidden(true)
        #else
        return self
        #endif
    }

    /// Fingers live at the screen edges during play: make system edge swipes
    /// (home indicator, notification/control center) require the deliberate
    /// double-swipe while `active`.
    func defersEdgeSwipes(_ active: Bool) -> some View {
        #if os(iOS)
        return defersSystemGestures(on: active ? .all : [])
        #else
        return self
        #endif
    }
}

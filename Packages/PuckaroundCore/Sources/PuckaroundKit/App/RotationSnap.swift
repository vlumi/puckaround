import SwiftUI

#if os(iOS)
import UIKit
#endif

extension View {
    /// While this view is on screen, an interface rotation snaps instead of
    /// animating. The board is physically stationary through a rotation (its
    /// quarter-turn cancels the interface's exactly), so the system's spin
    /// animation is pure noise — snapped, the table appears bolted in place and
    /// the labels and menus simply re-seat. Scoped to wherever it's applied (the
    /// table screen); the title and its modal keep the stock animation. Inert off
    /// iOS.
    func snapsOrientationChanges() -> some View {
        #if os(iOS)
        return background(RotationSnap())
        #else
        return self
        #endif
    }
}

#if os(iOS)
/// An invisible child controller: UIKit forwards `viewWillTransition` to
/// children, so this can switch animations off for exactly the span of the
/// rotation transition and back on when it completes.
private struct RotationSnap: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SnapController { SnapController() }
    func updateUIViewController(_ controller: SnapController, context: Context) {}
}

private final class SnapController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    override func viewWillTransition(
        to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        UIView.setAnimationsEnabled(false)
        // The coordinator's completion runs when the transition lands, even
        // if this view has gone away meanwhile — animations always come back.
        coordinator.animate(alongsideTransition: nil) { _ in
            UIView.setAnimationsEnabled(true)
        }
    }
}
#endif

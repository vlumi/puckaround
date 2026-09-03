import PuckaroundCore
import SwiftUI

#if os(iOS)
import UIKit

/// Captures every simultaneous touch and streams id-tagged events — the
/// shared-table input surface (SwiftUI gestures only track one touch).
struct MultiTouchSurface: UIViewRepresentable {
    let game: HockeyGame

    func makeUIView(context: Context) -> TouchCaptureView {
        let view = TouchCaptureView()
        view.game = game
        return view
    }

    func updateUIView(_ view: TouchCaptureView, context: Context) {
        view.game = game
    }
}

final class TouchCaptureView: UIView {
    weak var game: HockeyGame?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    private func touchID(_ touch: UITouch) -> TouchID {
        ObjectIdentifier(touch).hashValue
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            game?.touchBegan(id: touchID(touch), at: touch.location(in: self))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            game?.touchMoved(id: touchID(touch), at: touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            game?.touchEnded(id: touchID(touch))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            game?.touchCancelled(id: touchID(touch))
        }
    }
}

/// Defers the system edge gestures (home indicator, control/notification
/// center) and hides the home indicator while the table is on screen, so a
/// fingertip skating along a screen edge mid-rally doesn't trip the app switcher
/// on the first brush. iOS never lets an app *block* the home swipe — a
/// deliberate swipe still leaves — but deferring makes it take a second.
///
/// Why not just override the preferences on a representable's controller: those
/// getters are only consulted on the controller that owns the screen (the
/// window's root hosting controller), never on a nested SwiftUI child, and the
/// root doesn't forward to arbitrary children. So the controller installs itself
/// as the root's forwarded child (`childFor…`), which UIKit *does* consult, via
/// a one-time swizzle of those two getters, then asks the root to re-query.
struct EdgeGestureGuard: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GestureGuardController {
        GestureGuardController()
    }
    func updateUIViewController(_ controller: GestureGuardController, context: Context) {}
}

final class GestureGuardController: UIViewController {
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false  // never eat the game's touches
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        UIViewController.enableGestureGuardForwarding()
        GestureGuardController.active = (parent == nil) ? nil : self
        root?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        root?.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }

    private var root: UIViewController? { view.window?.rootViewController }

    /// The guard currently on screen, if any — the root forwards its preferences
    /// to this while the table is up.
    fileprivate weak static var active: GestureGuardController?
}

extension UIViewController {
    /// Swizzle the two `childFor…` getters once so every controller forwards to
    /// the active guard — the mechanism the root uses to honor the guard's
    /// deferral. Idempotent.
    static func enableGestureGuardForwarding() {
        guard !gestureGuardForwardingEnabled else { return }
        gestureGuardForwardingEnabled = true
        swizzle(
            #selector(getter: childForScreenEdgesDeferringSystemGestures),
            to: #selector(getter: paChildForScreenEdges))
        swizzle(
            #selector(getter: childForHomeIndicatorAutoHidden),
            to: #selector(getter: paChildForHomeIndicator))
    }

    private static func swizzle(_ original: Selector, to replacement: Selector) {
        guard let a = class_getInstanceMethod(UIViewController.self, original),
            let b = class_getInstanceMethod(UIViewController.self, replacement)
        else { return }
        method_exchangeImplementations(a, b)
    }

    @objc private var paChildForScreenEdges: UIViewController? {
        // After the exchange this calls the ORIGINAL getter; fall back to the
        // active guard when the controller has no child of its own to defer to.
        paChildForScreenEdges ?? GestureGuardController.active
    }

    @objc private var paChildForHomeIndicator: UIViewController? {
        paChildForHomeIndicator ?? GestureGuardController.active
    }
}

private var gestureGuardForwardingEnabled = false
#endif

/// The input surface over the table: real multitouch on iOS, a single-pointer
/// fallback elsewhere so the macOS test build keeps compiling.
struct InputSurface: View {
    let game: HockeyGame

    var body: some View {
        #if os(iOS)
        MultiTouchSurface(game: game)
        #else
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // The first change begins the touch (a no-op afterwards
                        // for the same id); later ones just move it.
                        game.touchBegan(id: 0, at: value.startLocation)
                        game.touchMoved(id: 0, at: value.location)
                    }
                    .onEnded { _ in
                        game.touchEnded(id: 0)
                    }
            )
        #endif
    }
}

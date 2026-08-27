import PuckaroundCore
import SwiftUI

#if os(iOS)
import UIKit

/// Captures every simultaneous touch and streams id-tagged events — the
/// shared-table input surface (SwiftUI gestures only track one touch).
struct MultiTouchSurface: UIViewRepresentable {
    let sandbox: Sandbox

    func makeUIView(context: Context) -> TouchCaptureView {
        let view = TouchCaptureView()
        view.sandbox = sandbox
        return view
    }

    func updateUIView(_ view: TouchCaptureView, context: Context) {
        view.sandbox = sandbox
    }
}

final class TouchCaptureView: UIView {
    weak var sandbox: Sandbox?

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
            sandbox?.touchBegan(
                id: touchID(touch), at: touch.location(in: self), time: touch.timestamp)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            sandbox?.touchMoved(
                id: touchID(touch), at: touch.location(in: self), time: touch.timestamp)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            sandbox?.touchEnded(id: touchID(touch))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            sandbox?.touchEnded(id: touchID(touch))
        }
    }
}
#endif

/// The input surface over the table: real multitouch on iOS, a single-pointer
/// fallback elsewhere so the macOS test build keeps compiling.
struct InputSurface: View {
    let sandbox: Sandbox

    var body: some View {
        #if os(iOS)
        MultiTouchSurface(sandbox: sandbox)
        #else
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let now = Date().timeIntervalSinceReferenceDate
                        // The first change begins the touch (a no-op afterwards
                        // for the same id); later ones just move it.
                        sandbox.touchBegan(id: 0, at: value.startLocation, time: now)
                        sandbox.touchMoved(id: 0, at: value.location, time: now)
                    }
                    .onEnded { _ in
                        sandbox.touchEnded(id: 0)
                    }
            )
        #endif
    }
}

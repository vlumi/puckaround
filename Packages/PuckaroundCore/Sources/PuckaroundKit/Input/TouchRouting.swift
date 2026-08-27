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
            game?.touchEnded(id: touchID(touch))
        }
    }
}
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

import PuckaroundCore
import SwiftUI

public struct GameView: View {
    @StateObject private var game = HockeyGame()

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Everything that reacts to the sim lives inside the timeline
                // closure, so it re-evaluates with the frame without publishing
                // anything. Layered, not stacked: the ZStack matters.
                TimelineView(.animation) { timeline in
                    let scene = game.frame(at: timeline.date.timeIntervalSinceReferenceDate)
                    ZStack {
                        Canvas { context, size in
                            RinkRenderer.draw(scene, in: &context, size: size)
                        }
                        InputSurface(game: game)
                        // ABOVE the input surface, or the multitouch view eats
                        // the tap and the button never fires.
                        if case .finished = scene.rink.phase {
                            restartButton
                                .position(x: scene.tableRect.midX, y: scene.tableRect.midY)
                        }
                    }
                }
            }
            .onAppear { game.layout(screen: geo.size) }
            .onChangeCompat(of: geo.size) { size in game.layout(screen: size) }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    /// Sits on the centre line when the game is over — the only way to start
    /// over, since a game in progress is finished by playing it. An icon rather
    /// than a word, and a rotationally symmetric one, because it is read from
    /// both ends of the table at once; the WIN / LOSE verdicts are drawn on the
    /// ice, each facing its own player.
    private var restartButton: some View {
        Button {
            game.newGame()
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 34, weight: .bold))
                .padding(22)
                .background(Circle().fill(RinkRenderer.ground))
                .foregroundStyle(RinkRenderer.ice)
        }
        .accessibilityLabel(Text("New game", bundle: .module))
    }
}

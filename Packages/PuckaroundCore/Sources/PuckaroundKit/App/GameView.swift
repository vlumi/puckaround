import PuckaroundCore
import SwiftUI

public struct GameView: View {
    @StateObject private var game = HockeyGame()

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // The whole frame lives inside the timeline closure so the win
                // banner re-evaluates with the sim, without publishing anything.
                TimelineView(.animation) { timeline in
                    let scene = game.frame(at: timeline.date.timeIntervalSinceReferenceDate)
                    Canvas { context, size in
                        RinkRenderer.draw(scene, in: &context, size: size)
                    }
                    if case .finished(let winner) = scene.rink.phase {
                        winBanner(winner)
                    }
                }
                InputSurface(game: game)
                hud
            }
            .onAppear { game.layout(screen: geo.size) }
            .onChangeCompat(of: geo.size) { size in game.layout(screen: size) }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    /// Stand-in until the front door exists: a corner button to start over.
    private var hud: some View {
        VStack {
            HStack {
                Button {
                    game.newGame()
                } label: {
                    Text("New game", bundle: .module)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(12)
            Spacer()
        }
    }

    private func winBanner(_ winner: PlayerID) -> some View {
        VStack(spacing: 16) {
            Text("Player \(winner.rawValue + 1) wins", bundle: .module)
                .font(.title.weight(.bold))
            Button {
                game.newGame()
            } label: {
                Text("New game", bundle: .module)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

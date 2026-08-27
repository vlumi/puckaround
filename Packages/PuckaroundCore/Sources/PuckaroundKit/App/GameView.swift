import PuckaroundCore
import SwiftUI

public struct GameView: View {
    @StateObject private var sandbox = Sandbox()

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                TimelineView(.animation) { timeline in
                    let scene = sandbox.frame(at: timeline.date.timeIntervalSinceReferenceDate)
                    Canvas { context, size in
                        RinkRenderer.draw(scene, in: &context, size: size)
                    }
                }
                InputSurface(sandbox: sandbox)
                hud
            }
            .onAppear { sandbox.layout(screen: geo.size) }
            .onChangeCompat(of: geo.size) { size in sandbox.layout(screen: size) }
        }
        .background(RinkRenderer.ground.ignoresSafeArea())
        .statusBarHiddenIfAvailable()
        .persistentSystemOverlays(.hidden)
        .defersEdgeSwipes(true)
    }

    /// Stand-in controls until the front door exists: who is at the table, and
    /// a serve.
    private var hud: some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    sandbox.cyclePlayers()
                } label: {
                    Text("Players: \(sandbox.lineup.playerCount)", bundle: .module)
                }
                if sandbox.lineup.playerCount == Lineup.maxPlayers {
                    Button {
                        sandbox.toggleTeams()
                    } label: {
                        if sandbox.lineup.teamed {
                            Text("Teams", bundle: .module)
                        } else {
                            Text("Free for all", bundle: .module)
                        }
                    }
                }
                Spacer()
                Button {
                    sandbox.serve()
                } label: {
                    Text("Serve", bundle: .module)
                }
            }
            .buttonStyle(.bordered)
            .padding(12)
            Spacer()
        }
    }
}

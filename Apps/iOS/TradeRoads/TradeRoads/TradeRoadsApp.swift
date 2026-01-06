import SwiftUI
import GameCore

@main
struct TradeRoadsApp: App {
    @State private var gameStateManager = GameStateManager()
    @State private var webSocketClient: WebSocketClient
    
    init() {
        let serverURL = URL(string: ProcessInfo.processInfo.environment["SERVER_URL"] ?? "ws://localhost:8080/ws")!
        _webSocketClient = State(initialValue: WebSocketClient(serverURL: serverURL))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gameStateManager)
                .environment(webSocketClient)
                .onAppear {
                    webSocketClient.setGameStateManager(gameStateManager)
                }
        }
    }
}

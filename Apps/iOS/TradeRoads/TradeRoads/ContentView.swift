import SwiftUI
import GameCore

struct ContentView: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Content
            switch gameState.currentScreen {
            case .login:
                LoginView()
            case .lobby:
                LobbyView()
            case .game:
                GameView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { gameState.showError },
            set: { _ in gameState.clearError() }
        )) {
            Button("OK") { gameState.clearError() }
        } message: {
            Text(gameState.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: Binding(
            get: { gameState.showResumePrompt },
            set: { if !$0 { gameState.showResumePrompt = false } }
        )) {
            ResumePromptView()
        }
        .onChange(of: gameState.pendingGameReconnect) { _, newValue in
            // When user chooses to resume game, initiate reconnect
            if let game = newValue {
                Task {
                    await webSocket.reconnect(gameId: game.gameId, lastSeenIndex: 0)
                    gameState.clearPendingReconnect()
                }
            }
        }
    }
}

// MARK: - Resume Prompt View

struct ResumePromptView: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1a1a2e").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Welcome Back!")
                        .font(.custom("Menlo-Bold", size: 24))
                        .foregroundColor(.white)
                    
                    Text("You have an active session")
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(Color(hex: "a0a0a0"))
                    
                    VStack(spacing: 16) {
                        // Show lobby option if exists
                        if let lobby = gameState.pendingSessionState?.activeLobby {
                            ResumeOptionButton(
                                title: "Resume Lobby",
                                subtitle: "\(lobby.lobbyName) (\(lobby.players.count) players)",
                                icon: "person.2.fill",
                                gradient: [Color(hex: "4ecdc4"), Color(hex: "45b7d1")]
                            ) {
                                gameState.resumeChoice(.lobby)
                                dismiss()
                            }
                        }
                        
                        // Show game option if exists
                        if let game = gameState.pendingSessionState?.activeGame {
                            ResumeOptionButton(
                                title: "Resume Game",
                                subtitle: "\(game.playerCount) players - \(game.playerNames.joined(separator: ", "))",
                                icon: "gamecontroller.fill",
                                gradient: [Color(hex: "e94560"), Color(hex: "c73659")]
                            ) {
                                gameState.resumeChoice(.game)
                                dismiss()
                            }
                        }
                        
                        // Always show start fresh option
                        if gameState.pendingSessionState?.activeLobby != nil {
                            ResumeOptionButton(
                                title: "Leave Lobby & Start Fresh",
                                subtitle: "Exit current lobby",
                                icon: "arrow.uturn.left.circle",
                                gradient: [Color(hex: "666666"), Color(hex: "444444")]
                            ) {
                                Task {
                                    await webSocket.leaveLobby()
                                    gameState.resumeChoice(.fresh)
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelResume()
                    }
                }
            }
        }
    }
    
    private func cancelResume() {
        // Clear pending state and dismiss without taking action
        gameState.pendingSessionState = nil
        gameState.showResumePrompt = false
        dismiss()
    }
}

struct ResumeOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("Menlo-Bold", size: 16))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.custom("Menlo", size: 11))
                        .foregroundColor(Color(hex: "888888"))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "555555"))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0f3460"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(gradient[0].opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environment(GameStateManager())
        .environment(WebSocketClient())
}

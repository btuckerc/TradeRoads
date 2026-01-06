import SwiftUI
import GameCore

struct LobbyView: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    @State private var showCreateLobby: Bool = false
    @State private var showJoinLobby: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Welcome,")
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(Color(hex: "a0a0a0"))
                    Text(gameState.displayName ?? "Player")
                        .font(.custom("Menlo-Bold", size: 24))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: logout) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "e94560"))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0f3460").opacity(0.5))
            )
            
            if let lobby = gameState.lobbyState {
                // In a lobby
                LobbyDetailView(lobby: lobby)
            } else {
                // Main menu
                mainMenu
            }
        }
        .padding()
        .sheet(isPresented: $showCreateLobby) {
            CreateLobbySheet()
        }
        .sheet(isPresented: $showJoinLobby) {
            JoinLobbySheet()
        }
    }
    
    private var mainMenu: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Create game button
            MenuButton(
                title: "CREATE GAME",
                subtitle: "Start a new lobby",
                icon: "plus.circle.fill",
                gradient: [Color(hex: "e94560"), Color(hex: "c73659")]
            ) {
                showCreateLobby = true
            }
            
            // Join game button
            MenuButton(
                title: "JOIN GAME",
                subtitle: "Enter a lobby code",
                icon: "person.2.fill",
                gradient: [Color(hex: "4ecdc4"), Color(hex: "45b7d1")]
            ) {
                showJoinLobby = true
            }
            
            Spacer()
        }
    }
    
    private func logout() {
        webSocket.reset()
        gameState.logout()
    }
}

// MARK: - Menu Button

struct MenuButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("Menlo-Bold", size: 18))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.custom("Menlo", size: 12))
                        .foregroundColor(Color(hex: "888888"))
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

// MARK: - Lobby Detail View

struct LobbyDetailView: View {
    let lobby: LobbyState
    
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        VStack(spacing: 20) {
            // Lobby Info
            HStack {
                VStack(alignment: .leading) {
                    Text(lobby.lobbyName)
                        .font(.custom("Menlo-Bold", size: 20))
                        .foregroundColor(.white)
                    
                    Text("Code: \(lobby.lobbyCode)")
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(Color(hex: "4ecdc4"))
                }
                
                Spacer()
                
                Button(action: leaveLobby) {
                    Text("LEAVE")
                        .font(.custom("Menlo-Bold", size: 12))
                        .foregroundColor(Color(hex: "e94560"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "e94560"), lineWidth: 1)
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0f3460").opacity(0.5))
            )
            
            // Players
            VStack(alignment: .leading, spacing: 12) {
                Text("PLAYERS (\(lobby.players.count)/\(lobby.playerMode.maxPlayers))")
                    .font(.custom("Menlo-Bold", size: 14))
                    .foregroundColor(Color(hex: "a0a0a0"))
                
                ForEach(lobby.players, id: \.userId) { player in
                    PlayerRow(player: player, isLocalPlayer: player.userId == gameState.userId)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "0f3460").opacity(0.5))
            )
            
            // Color Selection
            ColorSelectionView(
                selectedColor: currentPlayerColor,
                availableColors: lobby.availableColors
            )
            
            Spacer()
            
            // Bottom buttons
            HStack(spacing: 16) {
                // Ready Button
                Button(action: toggleReady) {
                    HStack {
                        Image(systemName: isReady ? "checkmark.circle.fill" : "circle")
                        Text(isReady ? "READY" : "NOT READY")
                            .font(.custom("Menlo-Bold", size: 14))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isReady ? Color(hex: "4ecdc4") : Color(hex: "333333"))
                    )
                    .foregroundColor(.white)
                }
                .disabled(currentPlayerColor == nil)
                
                // Start Button (host only)
                if isHost {
                    Button(action: startGame) {
                        Text("START")
                            .font(.custom("Menlo-Bold", size: 14))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: canStart ? [Color(hex: "e94560"), Color(hex: "c73659")] : [Color(hex: "444444"), Color(hex: "333333")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canStart)
                }
            }
        }
    }
    
    private var currentPlayerColor: PlayerColor? {
        lobby.players.first { $0.userId == gameState.userId }?.color
    }
    
    private var isReady: Bool {
        lobby.players.first { $0.userId == gameState.userId }?.isReady ?? false
    }
    
    private var isHost: Bool {
        lobby.hostId == gameState.userId
    }
    
    private var canStart: Bool {
        lobby.players.count >= lobby.playerMode.minPlayers &&
        lobby.players.allSatisfy { $0.isReady } &&
        lobby.players.allSatisfy { $0.color != nil }
    }
    
    private func leaveLobby() {
        Task {
            await webSocket.leaveLobby()
        }
    }
    
    private func toggleReady() {
        Task {
            await webSocket.setReady(!isReady)
        }
    }
    
    private func startGame() {
        Task {
            await webSocket.startGame()
        }
    }
}

// MARK: - Player Row

struct PlayerRow: View {
    let player: LobbyPlayer
    let isLocalPlayer: Bool
    
    var body: some View {
        HStack {
            // Color indicator
            Circle()
                .fill(player.color?.swiftUIColor ?? Color(hex: "333333"))
                .frame(width: 12, height: 12)
            
            // Name
            Text(player.displayName)
                .font(.custom("Menlo", size: 14))
                .foregroundColor(.white)
            
            if isLocalPlayer {
                Text("(you)")
                    .font(.custom("Menlo", size: 12))
                    .foregroundColor(Color(hex: "666666"))
            }
            
            if player.isHost {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "ffd700"))
            }
            
            Spacer()
            
            // Ready status
            if player.isReady {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "4ecdc4"))
            } else {
                Image(systemName: "circle")
                    .foregroundColor(Color(hex: "555555"))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isLocalPlayer ? Color(hex: "0f3460") : Color.clear)
        )
    }
}

// MARK: - Color Selection View

struct ColorSelectionView: View {
    let selectedColor: PlayerColor?
    let availableColors: [PlayerColor]
    
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT COLOR")
                .font(.custom("Menlo-Bold", size: 14))
                .foregroundColor(Color(hex: "a0a0a0"))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(PlayerColor.baseModeColors, id: \.self) { color in
                    ColorButton(
                        color: color,
                        isSelected: color == selectedColor,
                        isAvailable: availableColors.contains(color) || color == selectedColor
                    ) {
                        selectColor(color)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "0f3460").opacity(0.5))
        )
    }
    
    private func selectColor(_ color: PlayerColor) {
        Task {
            await webSocket.selectColor(color)
        }
    }
}

struct ColorButton: View {
    let color: PlayerColor
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.swiftUIColor)
                    .frame(height: 50)
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 3)
                    
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }
                
                if !isAvailable {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                    
                    Image(systemName: "xmark")
                        .foregroundColor(Color(hex: "666666"))
                }
            }
        }
        .disabled(!isAvailable)
    }
}

// MARK: - Create Lobby Sheet

struct CreateLobbySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WebSocketClient.self) private var webSocket
    
    @State private var lobbyName: String = ""
    @State private var playerMode: PlayerMode = .threeToFour
    @State private var useBeginnerLayout: Bool = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1a1a2e").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    TextField("", text: $lobbyName, prompt: Text("Lobby Name").foregroundColor(Color(hex: "666666")))
                        .font(.custom("Menlo", size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "0f3460"))
                        )
                    
                    // Player Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLAYER MODE")
                            .font(.custom("Menlo-Bold", size: 12))
                            .foregroundColor(Color(hex: "a0a0a0"))
                        
                        Picker("", selection: $playerMode) {
                            Text("3-4 Players").tag(PlayerMode.threeToFour)
                            Text("5-6 Players").tag(PlayerMode.fiveToSix)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Beginner Layout
                    Toggle(isOn: $useBeginnerLayout) {
                        Text("Beginner Layout")
                            .font(.custom("Menlo", size: 14))
                            .foregroundColor(.white)
                    }
                    .tint(Color(hex: "4ecdc4"))
                    
                    Spacer()
                    
                    Button(action: createLobby) {
                        Text("CREATE LOBBY")
                            .font(.custom("Menlo-Bold", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "e94560"), Color(hex: "c73659")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(lobbyName.isEmpty)
                    .opacity(lobbyName.isEmpty ? 0.6 : 1.0)
                }
                .padding()
            }
            .navigationTitle("Create Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createLobby() {
        Task {
            await webSocket.createLobby(name: lobbyName, playerMode: playerMode, useBeginnerLayout: useBeginnerLayout)
            dismiss()
        }
    }
}

// MARK: - Join Lobby Sheet

struct JoinLobbySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WebSocketClient.self) private var webSocket
    
    @State private var lobbyCode: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1a1a2e").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    TextField("", text: $lobbyCode, prompt: Text("Enter Code").foregroundColor(Color(hex: "666666")))
                        .font(.custom("Menlo-Bold", size: 32))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "0f3460"))
                        )
                        .onChange(of: lobbyCode) { _, newValue in
                            lobbyCode = String(newValue.uppercased().prefix(4))
                        }
                    
                    Text("Enter the 4-character code")
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(Color(hex: "888888"))
                    
                    Spacer()
                    
                    Button(action: joinLobby) {
                        Text("JOIN LOBBY")
                            .font(.custom("Menlo-Bold", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "4ecdc4"), Color(hex: "45b7d1")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(lobbyCode.count != 4)
                    .opacity(lobbyCode.count != 4 ? 0.6 : 1.0)
                }
                .padding()
            }
            .navigationTitle("Join Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func joinLobby() {
        Task {
            await webSocket.joinLobby(code: lobbyCode)
            dismiss()
        }
    }
}

// MARK: - PlayerColor Extension

extension PlayerColor {
    var swiftUIColor: Color {
        switch self {
        case .red: return Color(hex: "e74c3c")
        case .blue: return Color(hex: "3498db")
        case .orange: return Color(hex: "e67e22")
        case .white: return Color(hex: "ecf0f1")
        case .green: return Color(hex: "27ae60")
        case .brown: return Color(hex: "8b4513")
        }
    }
}

#Preview {
    LobbyView()
        .environment(GameStateManager())
        .environment(WebSocketClient())
}


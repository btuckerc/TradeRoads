import SwiftUI
import GameCore

struct LoginView: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    @State private var username: String = ""
    @State private var isConnecting: Bool = false
    @State private var connectionError: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Title
            VStack(spacing: 8) {
                Text("TRADE")
                    .font(.custom("Menlo-Bold", size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("ROADS")
                    .font(.custom("Menlo-Bold", size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "4ecdc4"), Color(hex: "45b7d1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .shadow(color: Color(hex: "e94560").opacity(0.5), radius: 20)
            
            // Subtitle
            Text("A CATAN-INSPIRED ADVENTURE")
                .font(.custom("Menlo", size: 14))
                .foregroundColor(Color(hex: "a0a0a0"))
                .tracking(4)
            
            Spacer()
            
            // Login Form
            VStack(spacing: 20) {
                TextField("", text: $username, prompt: Text("Enter username").foregroundColor(Color(hex: "666666")))
                    .font(.custom("Menlo", size: 18))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "0f3460"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "e94560").opacity(0.3), lineWidth: 1)
                            )
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                // Error message
                if let error = connectionError {
                    Text(error)
                        .font(.custom("Menlo", size: 12))
                        .foregroundColor(Color(hex: "e94560"))
                        .multilineTextAlignment(.center)
                }
                
                Button(action: connect) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("CONNECT")
                                .font(.custom("Menlo-Bold", size: 16))
                        }
                    }
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
                    .shadow(color: Color(hex: "e94560").opacity(0.4), radius: 10, y: 5)
                }
                .disabled(username.isEmpty || isConnecting)
                .opacity(username.isEmpty ? 0.6 : 1.0)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Version
            Text("v\(ProtocolVersion.current.stringValue)")
                .font(.custom("Menlo", size: 12))
                .foregroundColor(Color(hex: "555555"))
        }
        .padding()
        .onChange(of: webSocket.connectionState) { _, newState in
            handleConnectionStateChange(newState)
        }
    }
    
    private func connect() {
        isConnecting = true
        connectionError = nil
        webSocket.connect()
        // Authentication happens via connectionState change to .connected
    }
    
    private func handleConnectionStateChange(_ state: WebSocketConnectionState) {
        switch state {
        case .disconnected:
            isConnecting = false
            
        case .connecting:
            isConnecting = true
            connectionError = nil
            
        case .connected:
            // Connection established, authenticate
            // Only authenticate if we have a username (user initiated)
            guard !username.isEmpty else { return }
            Task {
                await webSocket.authenticate(identifier: username)
            }
            
        case .authenticating:
            // Still connecting
            break
            
        case .authenticated:
            // Success! GameStateManager handles navigation
            isConnecting = false
            connectionError = nil
            
        case .failed(let error):
            isConnecting = false
            connectionError = error
        }
    }
}

#Preview {
    LoginView()
        .environment(GameStateManager())
        .environment(WebSocketClient())
}


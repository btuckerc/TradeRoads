import SwiftUI
import SpriteKit
import GameCore

struct GameView: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(hex: "1a1a2e").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top HUD
                    GameTopHUD()
                    
                    // Board
                    BoardView()
                        .frame(maxHeight: .infinity)
                    
                    // Bottom HUD
                    GameBottomHUD()
                }
                
                // Winner overlay
                if let winnerId = gameState.gameState?.winnerId,
                   let winner = gameState.gameState?.player(id: winnerId) {
                    WinnerOverlay(winner: winner)
                }
            }
        }
    }
}

// MARK: - Game Top HUD

struct GameTopHUD: View {
    @Environment(GameStateManager.self) private var gameState
    
    var body: some View {
        HStack {
            // Current player
            if let activePlayer = gameState.activePlayer {
                HStack(spacing: 8) {
                    Circle()
                        .fill(activePlayer.color.swiftUIColor)
                        .frame(width: 16, height: 16)
                    
                    Text(activePlayer.displayName)
                        .font(.custom("Menlo-Bold", size: 14))
                        .foregroundColor(.white)
                    
                    if gameState.isLocalPlayerTurn {
                        Text("(YOUR TURN)")
                            .font(.custom("Menlo-Bold", size: 10))
                            .foregroundColor(Color(hex: "4ecdc4"))
                    }
                }
            }
            
            Spacer()
            
            // Turn and phase info
            if let turn = gameState.gameState?.turn {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Turn \(turn.turnNumber)")
                        .font(.custom("Menlo", size: 12))
                        .foregroundColor(Color(hex: "888888"))
                    
                    Text(turn.phase.displayName)
                        .font(.custom("Menlo-Bold", size: 12))
                        .foregroundColor(Color(hex: "4ecdc4"))
                }
            }
        }
        .padding()
        .background(Color(hex: "0f3460").opacity(0.9))
    }
}

// MARK: - Game Bottom HUD

struct GameBottomHUD: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        VStack(spacing: 12) {
            // Dice and resources
            HStack {
                // Dice display (not during setup)
                if !gameState.isSetupPhase {
                    DiceDisplay()
                }
                
                Spacer()
                
                // Local player resources
                if let player = gameState.localPlayer {
                    ResourceDisplay(resources: player.resources)
                }
            }
            
            // Setup phase UI
            if gameState.isSetupPhase {
                SetupPhaseHUD()
            }
            // Action buttons for main phase
            else if gameState.isLocalPlayerTurn {
                ActionButtons()
            }
        }
        .padding()
        .background(Color(hex: "0f3460").opacity(0.9))
    }
}

// MARK: - Setup Phase HUD

struct SetupPhaseHUD: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        VStack(spacing: 12) {
            if gameState.isLocalPlayerTurn {
                let pieceNeeded = gameState.setupPieceNeeded
                
                // Instructions
                HStack {
                    Image(systemName: pieceNeeded == .setupRoad ? "road.lanes" : "house.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "4ecdc4"))
                    
                    Text(pieceNeeded == .setupRoad ? "TAP AN EDGE TO PLACE ROAD" : "TAP A NODE TO PLACE SETTLEMENT")
                        .font(.custom("Menlo-Bold", size: 14))
                        .foregroundColor(.white)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "0f3460"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "4ecdc4").opacity(0.5), lineWidth: 1)
                        )
                )
                
                // Confirm button when selection is made
                if shouldShowConfirmButton {
                    Button(action: confirmPlacement) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("CONFIRM PLACEMENT")
                                .font(.custom("Menlo-Bold", size: 14))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "4ecdc4"), Color(hex: "45b7d1")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
            } else {
                // Waiting for other player
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "4ecdc4")))
                        .scaleEffect(0.8)
                    
                    Text("Waiting for other players...")
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(Color(hex: "888888"))
                }
                .padding()
            }
        }
    }
    
    private var shouldShowConfirmButton: Bool {
        let pieceNeeded = gameState.setupPieceNeeded
        if pieceNeeded == .setupSettlement && gameState.selectedNodeId != nil {
            return true
        }
        if pieceNeeded == .setupRoad && gameState.selectedEdgeId != nil {
            return true
        }
        return false
    }
    
    private func confirmPlacement() {
        let pieceNeeded = gameState.setupPieceNeeded
        
        Task {
            if pieceNeeded == .setupSettlement, let nodeId = gameState.selectedNodeId {
                await webSocket.buildSettlement(nodeId: nodeId, isFree: true)
                gameState.clearSelection()
            } else if pieceNeeded == .setupRoad, let edgeId = gameState.selectedEdgeId {
                await webSocket.buildRoad(edgeId: edgeId, isFree: true)
                gameState.clearSelection()
            }
        }
    }
}

// MARK: - Dice Display

struct DiceDisplay: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        HStack(spacing: 8) {
            if let roll = gameState.diceRoll {
                DieView(value: roll.0)
                DieView(value: roll.1)
                
                Text("= \(roll.0 + roll.1)")
                    .font(.custom("Menlo-Bold", size: 20))
                    .foregroundColor(.white)
            } else if gameState.isLocalPlayerTurn && gameState.currentPhase == GamePhase.preRoll {
                Button(action: rollDice) {
                    HStack {
                        Image(systemName: "dice")
                        Text("ROLL")
                    }
                    .font(.custom("Menlo-Bold", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "e94560"), Color(hex: "c73659")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func rollDice() {
        Task {
            await webSocket.rollDice()
        }
    }
}

struct DieView: View {
    let value: Int
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: 40, height: 40)
            
            Text("\(value)")
                .font(.custom("Menlo-Bold", size: 24))
                .foregroundColor(Color(hex: "1a1a2e"))
        }
    }
}

// MARK: - Resource Display

struct ResourceDisplay: View {
    let resources: ResourceBundle
    
    var body: some View {
        HStack(spacing: 12) {
            ResourcePill(type: .brick, count: resources.brick)
            ResourcePill(type: .lumber, count: resources.lumber)
            ResourcePill(type: .ore, count: resources.ore)
            ResourcePill(type: .grain, count: resources.grain)
            ResourcePill(type: .wool, count: resources.wool)
        }
    }
}

struct ResourcePill: View {
    let type: ResourceType
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(type.color)
                .frame(width: 12, height: 12)
            
            Text("\(count)")
                .font(.custom("Menlo-Bold", size: 14))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "0f3460"))
        )
    }
}

extension ResourceType {
    var color: Color {
        switch self {
        case .brick: return Color(hex: "c0392b")
        case .lumber: return Color(hex: "27ae60")
        case .ore: return Color(hex: "7f8c8d")
        case .grain: return Color(hex: "f39c12")
        case .wool: return Color(hex: "ecf0f1")
        }
    }
}

// MARK: - Action Buttons

struct ActionButtons: View {
    @Environment(GameStateManager.self) private var gameState
    @Environment(WebSocketClient.self) private var webSocket
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if gameState.currentPhase == .main {
                    ActionButton(title: "Road", icon: "road.lanes") {
                        // Building road - requires selecting location
                    }
                    
                    ActionButton(title: "Settlement", icon: "house.fill") {
                        // Building settlement
                    }
                    
                    ActionButton(title: "City", icon: "building.2.fill") {
                        // Building city
                    }
                    
                    ActionButton(title: "Dev Card", icon: "rectangle.stack.fill") {
                        Task { await webSocket.buyDevelopmentCard() }
                    }
                    
                    ActionButton(title: "Trade", icon: "arrow.left.arrow.right") {
                        // Open trade UI
                    }
                    
                    ActionButton(title: "End Turn", icon: "arrow.forward.circle", primary: true) {
                        Task { await webSocket.endTurn() }
                    }
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    var primary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(title)
                    .font(.custom("Menlo", size: 10))
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(primary ? Color(hex: "e94560") : Color(hex: "0f3460"))
            )
        }
    }
}

// MARK: - Board View (SpriteKit placeholder)

struct BoardView: View {
    @Environment(GameStateManager.self) private var gameState
    
    var body: some View {
        if let board = gameState.boardLayout {
            BoardSpriteView(boardLayout: board, gameState: gameState.gameState, manager: gameState)
        } else {
            Text("Loading board...")
                .foregroundColor(Color(hex: "888888"))
        }
    }
}

struct BoardSpriteView: UIViewRepresentable {
    let boardLayout: BoardLayout
    let gameState: GameState?
    let manager: GameStateManager
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        
        let scene = BoardScene(size: CGSize(width: 400, height: 500))
        scene.scaleMode = .aspectFit
        scene.boardLayout = boardLayout
        scene.gameState = gameState
        scene.selectionDelegate = context.coordinator
        view.presentScene(scene)
        
        return view
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        if let scene = uiView.scene as? BoardScene {
            scene.gameState = gameState
            scene.selectedNodeId = manager.selectedNodeId
            scene.selectedEdgeId = manager.selectedEdgeId
            scene.updateBoard()
        }
    }
    
    class Coordinator: BoardSceneDelegate {
        let manager: GameStateManager
        
        init(manager: GameStateManager) {
            self.manager = manager
        }
        
        func boardScene(_ scene: BoardScene, didSelectNode nodeId: Int) {
            Task { @MainActor in
                manager.selectNode(nodeId)
            }
        }
        
        func boardScene(_ scene: BoardScene, didSelectEdge edgeId: Int) {
            Task { @MainActor in
                manager.selectEdge(edgeId)
            }
        }
    }
}

protocol BoardSceneDelegate: AnyObject {
    func boardScene(_ scene: BoardScene, didSelectNode nodeId: Int)
    func boardScene(_ scene: BoardScene, didSelectEdge edgeId: Int)
}

// MARK: - Board Scene (SpriteKit)

class BoardScene: SKScene {
    var boardLayout: BoardLayout?
    var gameState: GameState?
    weak var selectionDelegate: BoardSceneDelegate?
    
    var selectedNodeId: Int?
    var selectedEdgeId: Int?
    
    private let hexSize: CGFloat = 40
    private var hexNodes: [Int: SKShapeNode] = [:]
    private var nodeMarkers: [Int: SKShapeNode] = [:]
    private var edgeMarkers: [Int: SKShapeNode] = [:]
    private var nodePositions: [Int: CGPoint] = [:]
    private var edgePositions: [Int: CGPoint] = [:]
    
    override func didMove(to view: SKView) {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        drawBoard()
    }
    
    func updateBoard() {
        updateBuildings()
        updateRobber()
        updateSelection()
    }
    
    private func drawBoard() {
        guard let board = boardLayout else { return }
        
        let centerX = size.width / 2
        let centerY = size.height / 2
        
        // Draw hexes
        for hex in board.hexes {
            let position = hexToPixel(q: hex.center.q, r: hex.center.r, centerX: centerX, centerY: centerY)
            let hexNode = createHexNode(terrain: hex.terrain, numberToken: hex.numberToken)
            hexNode.position = position
            hexNode.name = "hex-\(hex.hexId)"
            addChild(hexNode)
            hexNodes[hex.hexId] = hexNode
        }
        
        // Calculate and draw node positions
        drawNodes(board: board, centerX: centerX, centerY: centerY)
        
        // Calculate and draw edge positions
        drawEdges(board: board, centerX: centerX, centerY: centerY)
    }
    
    private func drawNodes(board: BoardLayout, centerX: CGFloat, centerY: CGFloat) {
        // Calculate node positions at hex vertices (corners), not hex centers
        // Each node is at a shared vertex of its adjacent hexes
        
        for node in board.nodes {
            guard !node.adjacentHexIds.isEmpty else { continue }
            
            // Get the first adjacent hex to calculate vertex positions
            guard let firstHexId = node.adjacentHexIds.first,
                  let firstHex = board.hexes.first(where: { $0.hexId == firstHexId }) else { continue }
            
            let hexCenter = hexToPixel(q: firstHex.center.q, r: firstHex.center.r, centerX: centerX, centerY: centerY)
            
            // Calculate all 6 vertex positions of this hex
            var bestVertex: CGPoint?
            var bestScore = 0
            
            for vertexDir in 0..<6 {
                let vertexPos = vertexPosition(hexCenter: hexCenter, direction: vertexDir)
                
                // Check how many adjacent hexes share this vertex
                var matchCount = 0
                for otherHexId in node.adjacentHexIds {
                    if let otherHex = board.hexes.first(where: { $0.hexId == otherHexId }) {
                        let otherCenter = hexToPixel(q: otherHex.center.q, r: otherHex.center.r, centerX: centerX, centerY: centerY)
                        
                        // Check if this vertex matches any vertex of the other hex
                        for otherDir in 0..<6 {
                            let otherVertex = vertexPosition(hexCenter: otherCenter, direction: otherDir)
                            let distance = hypot(vertexPos.x - otherVertex.x, vertexPos.y - otherVertex.y)
                            if distance < 1.0 {  // Within 1 pixel tolerance
                                matchCount += 1
                                break
                            }
                        }
                    }
                }
                
                // The vertex shared by all adjacent hexes is our node position
                if matchCount > bestScore {
                    bestScore = matchCount
                    bestVertex = vertexPos
                }
            }
            
            if let nodePos = bestVertex {
                nodePositions[node.nodeId] = nodePos
                
                // Create node marker (small circle for interaction)
                let marker = SKShapeNode(circleOfRadius: 12)
                marker.fillColor = UIColor(white: 0.5, alpha: 0.3)
                marker.strokeColor = .white
                marker.lineWidth = 1
                marker.position = nodePos
                marker.name = "node-\(node.nodeId)"
                marker.zPosition = 10
                addChild(marker)
                nodeMarkers[node.nodeId] = marker
            }
        }
    }
    
    /// Calculate a vertex position for a hex at the given direction (0-5).
    /// Direction 0 is at angle -π/6 (pointing right-down for pointy-top hex).
    private func vertexPosition(hexCenter: CGPoint, direction: Int) -> CGPoint {
        let angle = CGFloat.pi / 3.0 * CGFloat(direction) - CGFloat.pi / 6.0
        let x = hexCenter.x + hexSize * cos(angle)
        let y = hexCenter.y + hexSize * sin(angle)
        return CGPoint(x: x, y: y)
    }
    
    private func drawEdges(board: BoardLayout, centerX: CGFloat, centerY: CGFloat) {
        for edge in board.edges {
            guard let pos1 = nodePositions[edge.nodeIds.0],
                  let pos2 = nodePositions[edge.nodeIds.1] else { continue }
            
            let midpoint = CGPoint(x: (pos1.x + pos2.x) / 2, y: (pos1.y + pos2.y) / 2)
            edgePositions[edge.edgeId] = midpoint
            
            // Create edge marker (line between nodes)
            let path = CGMutablePath()
            path.move(to: pos1)
            path.addLine(to: pos2)
            
            let marker = SKShapeNode(path: path)
            marker.strokeColor = UIColor(white: 0.5, alpha: 0.3)
            marker.lineWidth = 6
            marker.lineCap = .round
            marker.name = "edge-\(edge.edgeId)"
            marker.zPosition = 5
            addChild(marker)
            edgeMarkers[edge.edgeId] = marker
        }
    }
    
    private func createHexNode(terrain: TerrainType, numberToken: Int?) -> SKShapeNode {
        let path = hexPath(size: hexSize)
        let node = SKShapeNode(path: path)
        node.fillColor = terrain.color
        node.strokeColor = .white
        node.lineWidth = 1
        node.zPosition = 1
        
        if let token = numberToken {
            let label = SKLabelNode(text: "\(token)")
            label.fontName = "Menlo-Bold"
            label.fontSize = 14
            label.fontColor = token == 6 || token == 8 ? .red : .black
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            
            let circle = SKShapeNode(circleOfRadius: 12)
            circle.fillColor = .white
            circle.strokeColor = .clear
            circle.zPosition = 2
            circle.addChild(label)
            node.addChild(circle)
        }
        
        return node
    }
    
    private func hexPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat.pi / 3 * CGFloat(i) - CGFloat.pi / 6
            let x = size * cos(angle)
            let y = size * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
    
    private func hexToPixel(q: Int, r: Int, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        let sqrtThree: CGFloat = sqrt(3)
        let qFloat = CGFloat(q)
        let rFloat = CGFloat(r)
        let xOffset = hexSize * (sqrtThree * qFloat + sqrtThree / 2 * rFloat)
        let yOffset = hexSize * (1.5 * rFloat)
        return CGPoint(x: centerX + xOffset, y: centerY - yOffset)
    }
    
    private func updateBuildings() {
        guard let state = gameState else { return }
        
        // Draw settlements
        for (nodeId, playerId) in state.buildings.settlements {
            if let marker = nodeMarkers[nodeId], let player = state.player(id: playerId) {
                marker.fillColor = player.color.uiColor
                marker.strokeColor = .white
                marker.lineWidth = 2
            }
        }
        
        // Draw cities (larger)
        for (nodeId, playerId) in state.buildings.cities {
            if let marker = nodeMarkers[nodeId], let player = state.player(id: playerId) {
                marker.fillColor = player.color.uiColor
                marker.strokeColor = .white
                marker.lineWidth = 3
                // Make it bigger to indicate city
                marker.setScale(1.5)
            }
        }
        
        // Draw roads
        for (edgeId, playerId) in state.buildings.roads {
            if let marker = edgeMarkers[edgeId], let player = state.player(id: playerId) {
                marker.strokeColor = player.color.uiColor
                marker.lineWidth = 6
            }
        }
    }
    
    private func updateSelection() {
        // Reset all markers to default
        for (nodeId, marker) in nodeMarkers {
            if gameState?.buildings.settlements[nodeId] == nil && gameState?.buildings.cities[nodeId] == nil {
                if nodeId == selectedNodeId {
                    marker.fillColor = UIColor(red: 0.3, green: 0.8, blue: 0.8, alpha: 0.8)
                    marker.strokeColor = .cyan
                    marker.lineWidth = 3
                } else {
                    marker.fillColor = UIColor(white: 0.5, alpha: 0.3)
                    marker.strokeColor = .white
                    marker.lineWidth = 1
                }
            }
        }
        
        for (edgeId, marker) in edgeMarkers {
            if gameState?.buildings.roads[edgeId] == nil {
                if edgeId == selectedEdgeId {
                    marker.strokeColor = .cyan
                    marker.lineWidth = 8
                } else {
                    marker.strokeColor = UIColor(white: 0.5, alpha: 0.3)
                    marker.lineWidth = 6
                }
            }
        }
    }
    
    private func updateRobber() {
        guard let hexId = gameState?.robberHexId,
              let hexNode = hexNodes[hexId] else { return }
        
        let robber = childNode(withName: "robber") as? SKShapeNode ?? {
            let r = SKShapeNode(circleOfRadius: 10)
            r.fillColor = .black
            r.strokeColor = .white
            r.lineWidth = 2
            r.name = "robber"
            r.zPosition = 20
            addChild(r)
            return r
        }()
        
        robber.position = hexNode.position
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Check for node touches first (they're on top)
        for (nodeId, position) in nodePositions {
            let distance = hypot(location.x - position.x, location.y - position.y)
            if distance < 20 {
                // Check if this node is available (no building)
                if gameState?.buildings.settlements[nodeId] == nil && gameState?.buildings.cities[nodeId] == nil {
                    selectionDelegate?.boardScene(self, didSelectNode: nodeId)
                    return
                }
            }
        }
        
        // Check for edge touches
        for (edgeId, position) in edgePositions {
            let distance = hypot(location.x - position.x, location.y - position.y)
            if distance < 25 {
                // Check if this edge is available (no road)
                if gameState?.buildings.roads[edgeId] == nil {
                    selectionDelegate?.boardScene(self, didSelectEdge: edgeId)
                    return
                }
            }
        }
    }
}

extension TerrainType {
    var color: UIColor {
        switch self {
        case .hills: return UIColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0)
        case .forest: return UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
        case .mountains: return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        case .fields: return UIColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 1.0)
        case .pasture: return UIColor(red: 0.6, green: 0.8, blue: 0.4, alpha: 1.0)
        case .desert: return UIColor(red: 0.9, green: 0.85, blue: 0.7, alpha: 1.0)
        }
    }
}

extension PlayerColor {
    var uiColor: UIColor {
        switch self {
        case .red: return UIColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
        case .blue: return UIColor(red: 0.20, green: 0.60, blue: 0.86, alpha: 1.0)
        case .orange: return UIColor(red: 0.90, green: 0.49, blue: 0.13, alpha: 1.0)
        case .white: return UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1.0)
        case .green: return UIColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1.0)
        case .brown: return UIColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        }
    }
}

// MARK: - Winner Overlay

struct WinnerOverlay: View {
    let winner: Player
    
    @Environment(GameStateManager.self) private var gameState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("🏆")
                    .font(.system(size: 80))
                
                Text("\(winner.displayName) WINS!")
                    .font(.custom("Menlo-Bold", size: 32))
                    .foregroundColor(winner.color.swiftUIColor)
                
                Button("Back to Lobby") {
                    gameState.currentScreen = .lobby
                }
                .font(.custom("Menlo-Bold", size: 16))
                .foregroundColor(.white)
                .padding()
                .background(Color(hex: "e94560"))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - GamePhase Extension

extension GamePhase {
    var displayName: String {
        switch self {
        case .setup: return "Setup"
        case .preRoll: return "Roll Dice"
        case .main: return "Build/Trade"
        case .movingRobber: return "Move Robber"
        case .stealing: return "Steal"
        case .discarding: return "Discarding"
        case .ended: return "Game Over"
        }
    }
}

#Preview {
    GameView()
        .environment(GameStateManager())
        .environment(WebSocketClient())
}


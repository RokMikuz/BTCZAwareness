// BTCZTetrisView.swift – 100 % CELOTNA – TETRIS Z POPOLNOMA PORAVNANIMI TETROMINOJI MED PADANJEM
import SwiftUI

struct BTCZTetrisView: View {
    @Environment(\.dismiss) private var dismiss
    
    // GRID
    private let columns = 10
    private let rows = 20
    
    @State private var grid: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 20)
    
    // TETROMINOJI
    private let tetrominoes: [Tetromino] = [
        Tetromino(rotations: [
            [["🟦"], ["🟦"], ["🟦"], ["🟦"]],
            [["🟦","🟦","🟦","🟦"]]
        ]),
        Tetromino(rotations: [
            [["🟨","🟨"],
             ["🟨","🟨"]]
        ]),
        Tetromino(rotations: [
            [["  ","🟪","  "],
             ["🟪","🟪","🟪"]],
            [["🟪","  "],
             ["🟪","🟪"],
             ["🟪","  "]],
            [["🟪","🟪","🟪"],
             ["  ","🟪","  "]],
            [["  ","🟪"],
             ["🟪","🟪"],
             ["  ","🟪"]]
        ]),
        Tetromino(rotations: [
            [["  ","🟩","🟩"],
             ["🟩","🟩","  "]],
            [["🟩","  "],
             ["🟩","🟩"],
             ["  ","🟩"]]
        ]),
        Tetromino(rotations: [
            [["🟥","🟥","  "],
             ["  ","🟥","🟥"]],
            [["  ","🟥"],
             ["🟥","🟥"],
             ["🟥","  "]]
        ]),
        Tetromino(rotations: [
            [["🟧","  ","  "],
             ["🟧","🟧","🟧"]],
            [["🟧","🟧"],
             ["🟧","  "],
             ["🟧","  "]],
            [["🟧","🟧","🟧"],
             ["  ","  ","🟧"]],
            [["  ","🟧"],
             ["  ","🟧"],
             ["🟧","🟧"]]
        ]),
        Tetromino(rotations: [
            [["  ","  ","🟧"],
             ["🟧","🟧","🟧"]],
            [["🟧","  "],
             ["🟧","  "],
             ["🟧","🟧"]],
            [["🟧","🟧","🟧"],
             ["🟧","  ","  "]],
            [["🟧","🟧"],
             ["  ","🟧"],
             ["  ","🟧"]]
        ])
    ]
    
    @State private var currentTetromino: Tetromino = Tetromino(rotations: [
        [["🟦"], ["🟦"], ["🟦"], ["🟦"]],
        [["🟦","🟦","🟦","🟦"]]
    ])
    @State private var currentRotation = 0
    @State private var currentPosition = CGPoint(x: 4, y: -4)
    
    @State private var clearingRows: Set<Int> = []
    @State private var lastPlacedCells: [(Int, Int)] = []
    @State private var controlIconSize: CGFloat = 56
    @State private var gridContainerSize: CGSize = .zero
    
    @State private var currentBalance: Int = 0
    @State private var showInsufficientAlert: Bool = false
    @State private var showGameOverAnim = false
    @State private var score = 0
    @State private var linesCleared = 0
    @State private var isGameOver = false
    @State private var isPlaying = false
    @State private var nextTetromino: Tetromino? = nil

    @State private var heldTetromino: Tetromino? = nil
    @State private var canHoldThisTurn: Bool = true
    @State private var isPaused: Bool = false
    @State private var isSoftDropping: Bool = false

    @State private var hasPlayedOnce: Bool = UserDefaults.standard.bool(forKey: "tetrisHasPlayedOnce")
    
    @State private var level = 1
    @State private var dropInterval: TimeInterval = 0.8
    
    // Coin fly animation state
    @State private var coinBursts: [UUID: [Coin]] = [:]
    
    // NAGRADA + DNEVNI LIMIT
    private let rewardPerLine = 3
    private let maxRewardPerDay = 150
    private var maxLinesPerDay: Int { maxRewardPerDay / rewardPerLine }
    @State private var rewardToday = 0
    @State private var lastPlayDate: Date? = UserDefaults.standard.object(forKey: "tetrisLastPlay") as? Date
    
    // TIMER
    @State private var gameTimer: Timer? = nil

    // New state variable for back button press animation
    @State private var backPressed = false

    private func interval(for level: Int) -> TimeInterval { max(0.15, 0.8 - 0.08 * Double(level - 1)) }
    
    private var backgroundGradient: LinearGradient {
        let top: UnitPoint = .top
        let bottom: UnitPoint = .bottom
        let startColor: Color = Color.indigo.opacity(0.9)
        let endColor: Color = Color.black
        let colors: [Color] = [startColor, endColor]
        return LinearGradient(colors: colors, startPoint: top, endPoint: bottom)
    }
    
    var body: some View {
        ZStack {
            backgroundGradientView()
            mainContent()
        }
        .alert("Not enough BTCZ", isPresented: $showInsufficientAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need 50 BTCZ to start a new game.")
        }
        .overlay(
            Group {
                if isPaused && isPlaying && !isGameOver {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 14) {
                                Text("Paused").font(.largeTitle.bold()).foregroundStyle(.white)
                                Button("Resume") { togglePause() }
                                    .font(.title3.bold())
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(.green.opacity(0.85))
                                    .cornerRadius(12)
                            }
                        )
                        .transition(.opacity)
                }
            }
        )
        .navigationTitle("BTCZ Tetris")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    backPressed = true
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        backPressed = false
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                        .scaleEffect(backPressed ? 0.92 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: backPressed)
                }
            }
        }
    }
    
    @ViewBuilder
    private func backgroundGradientView() -> some View {
        backgroundGradient
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func mainContent() -> some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let availableHeight = proxy.size.height - safeTop - safeBottom
            // Heuristic thresholds
            let isCompact = availableHeight < 700
            
            Group {
                if isCompact {
                    ScrollView {
                        contentStack(isCompact: isCompact, availableHeight: availableHeight)
                            .padding(.bottom, 20)
                    }
                } else {
                    contentStack(isCompact: isCompact, availableHeight: availableHeight)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            checkDailyLimit()
            currentBalance = PointsManager.shared.currentPoints
        }
        .overlay(gameOverOverlay())
    }
    
    @ViewBuilder
    private func contentStack(isCompact: Bool, availableHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            nextPiecePreview()
            Spacer().frame(height: 8)
            gridContainerDynamic(availableHeight: availableHeight, isCompact: isCompact)
            startButtonIfNeeded()
            controlsIfNeededDynamic(isCompact: isCompact)
            scoreAndLimit()
            if rewardToday >= maxRewardPerDay {
                Text("Daily limit reached!\nCome back tomorrow")
                    .font(.title2)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: isCompact ? 8 : 16)
        }
    }
    
    @ViewBuilder
    private func gridContainerDynamic(availableHeight: CGFloat, isCompact: Bool) -> some View {
        // Reserve space for controls and labels; adjust heuristically and by device
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        // On iPad with plenty of height, reserve more space for the controls so they never get clipped
        let reservedBelow: CGFloat = {
            if isCompact { return 120 }
            if isPad { return 180 } // give controls more room on iPad
            return 135
        }()

        // Use a percentage of the available height for the grid; slightly smaller on iPad so controls remain visible
        let fraction: CGFloat = {
            if isCompact { return 0.76 }
            if isPad { return 0.84 }
            return 0.90
        }()

        let candidate = availableHeight * fraction
        let cappedByReserved = max(0, availableHeight - reservedBelow)
        // Ensure the grid does not exceed the space that leaves room for controls
        let targetHeight = max(320, min(cappedByReserved, candidate))

        return gridContainer()
            .frame(height: targetHeight)
    }
    
    @ViewBuilder
    private func nextPiecePreview() -> some View {
        VStack(spacing: 6) {
            Text("Next Piece")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            if let next = nextTetromino {
                nextPieceGridView(tetromino: next)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 52, height: 52)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.25))
        .cornerRadius(10)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }
    
    private func nextPieceGridView(tetromino: Tetromino) -> some View {
        // Use rotation 0 for preview
        let piece = tetromino.rotations.first ?? [[]]
        // Compute a compact grid of emojis
        return VStack(spacing: 1) {
            ForEach(0..<piece.count, id: \.self) { r in
                HStack(spacing: 1) {
                    ForEach(0..<piece[r].count, id: \.self) { c in
                        let s = piece[r][c]
                        let filled = isFilled(s)
                        Text(filled ? s : " ")
                            .font(.system(size: 12))
                            .frame(width: 14, height: 14, alignment: .center)
                            .background(
                                filled ? Color.black.opacity(0.35) : Color.clear
                            )
                            .cornerRadius(2)
                    }
                }
            }
        }
        .frame(width: 52, height: 52, alignment: .center)
        .opacity(0.95)
    }
    
    @ViewBuilder
    private func gridContainer() -> some View {
        ZStack {
            GeometryReader { geo in
                gridGeometryContent(geo: geo)
            }
        }
        .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
        //.frame(height: UIScreen.main.bounds.height * 0.58)  // REMOVED fixed height frame
        .layoutPriority(1)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("Score: \(score) BTCZ")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
            .padding(8)
            .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.9), lineWidth: 3)
        )
        .shadow(color: Color.yellow.opacity(0.7), radius: 20)
        .padding(.top, 8)
    }
    
    private func gridGeometryContent(geo: GeometryProxy) -> some View {
        // Break down complex expressions into explicit locals
        let columnsCount: CGFloat = CGFloat(columns)
        let rowsCount: CGFloat = CGFloat(rows)
        let cellSpacing: CGFloat = 1
        let availableWidth: CGFloat = geo.size.width
        let availableHeight: CGFloat = geo.size.height
        
        let cellSizeFromWidth = (availableWidth - (columnsCount - 1) * cellSpacing) / max(columnsCount, 1)
        let cellSizeFromHeight = (availableHeight - (rowsCount - 1) * cellSpacing) / max(rowsCount, 1)
        let rawCellSize = min(cellSizeFromWidth, cellSizeFromHeight)
        let cellSize: CGFloat = rawCellSize.isFinite && rawCellSize > 0 ? rawCellSize : 0
        
        let iconSize: CGFloat = max(44, min(72, cellSize * 1.8))
        let rawTotalWidth = columnsCount * cellSize + (columnsCount - 1) * cellSpacing
        let rawTotalHeight = rowsCount * cellSize + (rowsCount - 1) * cellSpacing
        let totalWidth: CGFloat = rawTotalWidth.isFinite && rawTotalWidth >= 0 ? rawTotalWidth : 0
        let totalHeight: CGFloat = rawTotalHeight.isFinite && rawTotalHeight >= 0 ? rawTotalHeight : 0
        
        let baseGrid = gridBase(totalWidth: totalWidth, totalHeight: totalHeight, cellSize: cellSize, cellSpacing: cellSpacing)
        let currentPiece = currentPieceOverlay(cellSize: cellSize, cellSpacing: cellSpacing)
        let ghost = ghostPieceOverlay(cellSize: cellSize, cellSpacing: cellSpacing)
        let coins = coinsOverlay(totalWidth: totalWidth, totalHeight: totalHeight)
        
        return ZStack(alignment: .topLeading) {
            baseGrid
            if totalWidth > 0 && totalHeight > 0 {
                currentPiece
                coins
            } else {
                Color.clear
            }
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
        .clipped()
        .onAppear {
            self.controlIconSize = iconSize
            self.gridContainerSize = CGSize(width: max(0, totalWidth), height: max(0, totalHeight))
        }
        .onChange(of: geo.size) { _ in
            self.controlIconSize = iconSize
            self.gridContainerSize = CGSize(width: max(0, totalWidth), height: max(0, totalHeight))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private func gridBase(totalWidth: CGFloat, totalHeight: CGFloat, cellSize: CGFloat, cellSpacing: CGFloat) -> some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        GridCellView(
                            content: grid[row][col],
                            cellSize: cellSize,
                            isClearing: clearingRows.contains(row),
                            isHighlighted: lastPlacedCells.contains(where: { $0.0 == row && $0.1 == col })
                        )
                    }
                }
            }
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
    }
    
    @ViewBuilder
    private func currentPieceOverlay(cellSize: CGFloat, cellSpacing: CGFloat) -> some View {
        if isPlaying && !isGameOver {
            let piece = currentTetromino.rotations[currentRotation]
            ForEach(0..<piece.count, id: \.self) { r in
                ForEach(0..<piece[r].count, id: \.self) { c in
                    if isFilled(piece[r][c]) {
                        let gridRow = Int(currentPosition.y) + r
                        let gridCol = Int(currentPosition.x) + c
                        if gridRow >= 0 && gridRow < rows && gridCol >= 0 && gridCol < columns {
                            let xOffset: CGFloat = CGFloat(gridCol) * (cellSize + cellSpacing)
                            let yOffset: CGFloat = CGFloat(gridRow) * (cellSize + cellSpacing)
                            CurrentPieceCellView(content: piece[r][c], cellSize: cellSize)
                                .offset(x: xOffset, y: yOffset)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func ghostPieceOverlay(cellSize: CGFloat, cellSpacing: CGFloat) -> some View {
        if isPlaying && !isGameOver {
            let piece = currentTetromino.rotations[currentRotation]
            let landingY = computeGhostLandingY(for: piece, from: Int(currentPosition.y))
            ForEach(0..<piece.count, id: \.self) { r in
                ForEach(0..<piece[r].count, id: \.self) { c in
                    if isFilled(piece[r][c]) {
                        let gridRow = landingY + r
                        let gridCol = Int(currentPosition.x) + c
                        if gridRow >= 0 && gridRow < rows && gridCol >= 0 && gridCol < columns {
                            let xOffset: CGFloat = CGFloat(gridCol) * (cellSize + cellSpacing)
                            let yOffset: CGFloat = CGFloat(gridRow) * (cellSize + cellSpacing)
                            Text(piece[r][c])
                                .font(.system(size: 26))
                                .frame(width: cellSize, height: cellSize)
                                .background(Color.clear)
                                .foregroundStyle(Color.white.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .offset(x: xOffset, y: yOffset)
                        }
                    }
                }
            }
        }
    }
    
    private func computeGhostLandingY(for piece: [[String]], from startY: Int) -> Int {
        var testY = startY
        while true {
            let nextY = testY + 1
            let canPlaceNext = canPlace(piece: piece, at: CGPoint(x: currentPosition.x, y: CGFloat(nextY)))
            if !canPlaceNext { break }
            testY = nextY
        }
        return testY
    }
    
    @ViewBuilder
    private func coinsOverlay(totalWidth: CGFloat, totalHeight: CGFloat) -> some View {
        let burstKeys: [UUID] = Array(coinBursts.keys)
        if !burstKeys.isEmpty {
            ForEach(burstKeys, id: \.self) { key in
                if let coins = coinBursts[key] {
                    CoinOverlayView(coins: coins)
                        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
                }
            }
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func startButtonIfNeeded() -> some View {
        if !isPlaying && !isGameOver {
            Text("New game costs 50 BTCZ")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            Button("START GAME") {
                startNewGame()
            }
            .font(.title2.bold())
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.green.opacity(0.8))
            .cornerRadius(20)
            .shadow(color: .green.opacity(0.6), radius: 15)
            .padding(.horizontal, 40)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func controlsIfNeeded() -> some View { EmptyView() }
    
    @ViewBuilder
    private func controlsIfNeededDynamic(isCompact: Bool) -> some View {
        if isPlaying && !isGameOver {
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            // Derive a dynamic base from grid container size to scale controls
            let minTap: CGFloat = isPad ? 56 : 48
            let maxTap: CGFloat = isPad ? 88 : 72
            let computed = max(minTap, min(maxTap, controlIconSize * (isCompact ? 0.9 : 1.1)))
            let sideOffset: CGFloat = 12
            let bottomPadding: CGFloat = isCompact ? 10 : 14

            if isPad {
                HStack(spacing: 24) {
                    // Left button at far left
                    Button { moveLeft() } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: computed))
                            .foregroundStyle(.orange)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move Left")

                    Spacer(minLength: 20)

                    // Center pair: Rotate + Hard Drop
                    HStack(spacing: 36) {
                        Button { rotate() } label: {
                            Image(systemName: "rotate.right.fill")
                                .font(.system(size: computed))
                                .foregroundStyle(.yellow)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Rotate")

                        Button { hardDrop() } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: max(computed, minTap + 6)))
                                .foregroundStyle(.red)
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Hard Drop")
                    }

                    Spacer(minLength: 20)

                    // Right button at far right
                    Button { moveRight() } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: computed))
                            .foregroundStyle(.orange)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move Right")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, bottomPadding)
            } else {
                let sideSpacing: CGFloat = isPad ? (isCompact ? 44 : 60) : (isCompact ? 28 : 40)
                let verticalSpacing: CGFloat = isPad ? (isCompact ? 10 : 14) : (isCompact ? 8 : 10)

                HStack(spacing: sideSpacing) {
                    Button { moveLeft() } label: {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: computed))
                            .foregroundStyle(.orange)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move Left")

                    HStack(spacing: verticalSpacing) {
                        Button { rotate() } label: {
                            Image(systemName: "rotate.right.fill")
                                .font(.system(size: computed))
                                .foregroundStyle(.yellow)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Rotate")

                        Button { hardDrop() } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: max(computed, minTap + 6)))
                                .foregroundStyle(.red)
                                .padding(10)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Hard Drop")
                    }

                    Button { moveRight() } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: computed))
                            .foregroundStyle(.orange)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Move Right")
                }
                .padding(.horizontal, isPad ? 24 : 16)
                .padding(.bottom, bottomPadding)
            }
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func scoreAndLimit() -> some View {
        VStack(spacing: 6) {
            Text("Score: \(score) BTCZ")
                .font(.title3.bold())
                .foregroundStyle(.green)
            Text("Lines: \(linesCleared) / 50  •  Level \(level)")
                .font(.title3)
                .foregroundStyle(rewardToday >= maxRewardPerDay ? .red : .white)
        }
        .padding(.top, 8)
    }
    
    @ViewBuilder
    private func gameOverOverlay() -> some View {
        if isGameOver {
            ZStack {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Game Over")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.red)
                    Text("You earned \(score) BTCZ")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("Balance: \(currentBalance) BTCZ")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                    Text("New game costs 50 BTCZ")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Button("New Game") {
                        if currentBalance >= 50 {
                            currentBalance -= 50
                            PointsManager.shared.currentPoints = currentBalance
                            PointsManager.shared.saveToServer()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showGameOverAnim = false
                            }
                            startNewGame()
                        } else {
                            showInsufficientAlert = true
                        }
                    }
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.purple.opacity(0.85))
                    .cornerRadius(14)
                    .shadow(color: .purple.opacity(0.5), radius: 10)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(radius: 20)
                .scaleEffect(showGameOverAnim ? 1 : 0.7)
                .opacity(showGameOverAnim ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showGameOverAnim)
            }
            .transition(.opacity.combined(with: .scale))
        } else {
            EmptyView()
        }
    }
    
    private func startNewGame() {
        // First game is free; subsequent games cost 50 BTCZ
        let startFee = 50
        currentBalance = PointsManager.shared.currentPoints
        if hasPlayedOnce {
            if currentBalance < startFee {
                showInsufficientAlert = true
                return
            }
            currentBalance -= startFee
            PointsManager.shared.currentPoints = currentBalance
            PointsManager.shared.saveToServer()
        } else {
            // Mark that the player has now played at least once
            hasPlayedOnce = true
            UserDefaults.standard.set(true, forKey: "tetrisHasPlayedOnce")
        }
        
        grid = Array(repeating: Array(repeating: "", count: columns), count: rows)
        score = 0
        linesCleared = 0
        isGameOver = false
        isPlaying = true
        showGameOverAnim = false
        
        isPaused = false
        isSoftDropping = false
        heldTetromino = nil
        canHoldThisTurn = true
        
        // Prepare pieces
        if let preparedNext = nextTetromino {
            currentTetromino = preparedNext
        } else {
            currentTetromino = tetrominoes.randomElement()!
        }
        nextTetromino = tetrominoes.randomElement()!
        currentRotation = 0
        currentPosition = CGPoint(x: 4, y: -4)
        
        level = 1
        dropInterval = interval(for: level)
        
        gameTimer?.invalidate()
        restartTimer()
        
        spawnPiece()
    }
    
    private func spawnPiece() {
        currentTetromino = nextTetromino ?? tetrominoes.randomElement()!
        nextTetromino = tetrominoes.randomElement()!
        currentRotation = 0
        currentPosition = CGPoint(x: 4, y: -4)
        canHoldThisTurn = true
        
        if !canPlacePiece() {
            gameOver()
        }
    }
    
    private func canPlacePiece() -> Bool {
        let piece = currentTetromino.rotations[currentRotation]
        return canPlace(piece: piece, at: currentPosition)
    }
    
    private func canPlace(piece: [[String]], at position: CGPoint) -> Bool {
        for row in 0..<piece.count {
            for col in 0..<piece[row].count {
                if isFilled(piece[row][col]) {
                    let gridRow = Int(position.y) + row
                    let gridCol = Int(position.x) + col
                    if gridRow >= rows || gridCol < 0 || gridCol >= columns || (gridRow >= 0 && grid[gridRow][gridCol] != "") {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    private func placePiece() {
        lastPlacedCells.removeAll()
        let piece = currentTetromino.rotations[currentRotation]
        for row in 0..<piece.count {
            for col in 0..<piece[row].count {
                if isFilled(piece[row][col]) {
                    let gridRow = Int(currentPosition.y) + row
                    let gridCol = Int(currentPosition.x) + col
                    if gridRow >= 0 && gridRow < rows && gridCol >= 0 && gridCol < columns {
                        grid[gridRow][gridCol] = piece[row][col]
                        lastPlacedCells.append((gridRow, gridCol))
                    }
                }
            }
        }
        canHoldThisTurn = true
    }
    
    private func moveDown() {
        if isPaused { return }
        currentPosition.y += 1
        
        if !canPlacePiece() {
            currentPosition.y -= 1
            placePiece()
            if pieceTouchesTopAfterPlacing() {
                gameOver()
                return
            }
            clearLines()
            spawnPiece()
        }
    }
    
    private func hardDrop() {
        if isPaused { return }
        while canPlacePiece() {
            currentPosition.y += 1
        }
        currentPosition.y -= 1
        placePiece()
        if pieceTouchesTopAfterPlacing() {
            gameOver()
            return
        }
        clearLines()
        spawnPiece()
    }
    
    private func moveLeft() {
        if isPaused { return }
        currentPosition.x -= 1
        if !canPlacePiece() {
            currentPosition.x += 1
        }
    }
    
    private func moveRight() {
        if isPaused { return }
        currentPosition.x += 1
        if !canPlacePiece() {
            currentPosition.x -= 1
        }
    }
    
    private func rotate() {
        if isPaused { return }
        let oldRotation = currentRotation
        currentRotation = (currentRotation + 1) % currentTetromino.rotations.count
        if !canPlacePiece() {
            currentRotation = oldRotation
        }
    }
    
    private func clearLines() {
        var rowsToClear: [Int] = []
        for row in (0..<rows).reversed() {
            if grid[row].allSatisfy({ $0 != "" }) {
                rowsToClear.append(row)
            }
        }
        guard !rowsToClear.isEmpty else {
            return
        }
        // Označi za animacijo
        clearingRows = Set(rowsToClear)
        
        spawnCoins(for: rowsToClear)

        // Po kratkem zamiku izvedi brisanje
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            for row in rowsToClear {
                grid.remove(at: row)
                grid.insert(Array(repeating: "", count: columns), at: 0)
                linesCleared += 1
            }
            updateLevelIfNeeded()
            if linesCleared >= 50 {
                gameOver()
            }
            // Nagrade
            let linesToClear = rowsToClear.count
            if linesToClear > 0 {
                let reward = linesToClear * rewardPerLine
                if rewardToday + reward <= maxRewardPerDay {
                    score += reward
                    rewardToday += reward
                    PointsManager.shared.currentPoints += reward
                    PointsManager.shared.saveToServer()
                } else {
                    let remaining = maxRewardPerDay - rewardToday
                    if remaining > 0 {
                        score += remaining
                        rewardToday += remaining
                        PointsManager.shared.currentPoints += remaining
                        PointsManager.shared.saveToServer()
                    }
                }
            }
            // Po animaciji počisti oznake
            clearingRows.removeAll()
        }
    }
    
    private func updateLevelIfNeeded() {
        let newLevel = max(1, (linesCleared / 5) + 1)
        if newLevel != level {
            level = newLevel
            // adjust speed
            dropInterval = interval(for: level)
            gameTimer?.invalidate()
            gameTimer = Timer.scheduledTimer(withTimeInterval: dropInterval, repeats: true) { _ in
                if !isGameOver && rewardToday < maxRewardPerDay {
                    moveDown()
                }
            }
        }
    }
    
    private func spawnCoins(for rows: [Int]) {
        guard !rows.isEmpty else { return }
        // Estimate grid cell size from last known gridContainerSize
        let cellSpacing: CGFloat = 1
        let columnsCount = CGFloat(columns)
        let rowsCount = CGFloat(self.rows)
        let cellSizeFromWidth = (gridContainerSize.width - (columnsCount - 1) * cellSpacing) / columnsCount
        let cellSizeFromHeight = (gridContainerSize.height - (rowsCount - 1) * cellSpacing) / rowsCount
        let cellSize = min(cellSizeFromWidth, cellSizeFromHeight)
        let totalWidth = columnsCount * cellSize + (columnsCount - 1) * cellSpacing
        // Start X positions distributed across the cleared row
        for row in rows {
            var coins: [Coin] = []
            for i in 0..<5 {
                let startX = CGFloat(i + 1) / 6.0 * totalWidth
                let startY = CGFloat(row) * (cellSize + cellSpacing) + cellSize / 2
                coins.append(Coin(position: CGPoint(x: startX, y: startY), opacity: 1, scale: 0.6, rotation: .degrees(0)))
            }
            let key = UUID()
            coinBursts[key] = coins
            
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                coinBursts[key] = coins.map { c in
                    var c2 = c
                    c2.scale = 1.0
                    return c2
                }
            }

            withAnimation(.easeOut(duration: 0.8)) {
                coinBursts[key] = coins.enumerated().map { idx, c in
                    var c2 = c
                    let targetX = max(0, gridContainerSize.width - 18)
                    let targetY: CGFloat = 14
                    c2.position = CGPoint(x: targetX, y: targetY)
                    c2.rotation = .degrees(Double(Int.random(in: -180...180)))
                    c2.scale = 0.8
                    return c2
                }
            }
            // Fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.easeOut(duration: 0.25)) {
                    coinBursts[key] = coinBursts[key]?.map { c in
                        var c2 = c
                        c2.opacity = 0
                        c2.scale = 0.5
                        c2.position = CGPoint(x: c.position.x, y: c.position.y - 20)
                        return c2
                    }
                }
            }
            // Remove after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                coinBursts.removeValue(forKey: key)
            }
        }
    }
    
    private func gameOver() {
        isGameOver = true
        isPlaying = false
        isPaused = false
        isSoftDropping = false
        gameTimer?.invalidate()
        UserDefaults.standard.set(Date(), forKey: "tetrisLastPlay")
        UserDefaults.standard.set(rewardToday, forKey: "tetrisRewardToday")
        
        currentBalance = PointsManager.shared.currentPoints
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showGameOverAnim = true
        }
    }
    
    private func checkDailyLimit() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastPlayDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if calendar.isDate(today, inSameDayAs: lastDay) {
                rewardToday = UserDefaults.standard.integer(forKey: "tetrisRewardToday")
            } else {
                rewardToday = 0
                UserDefaults.standard.set(0, forKey: "tetrisRewardToday")
            }
        } else {
            rewardToday = 0
        }
    }
    
    // Ali pravkar postavljeni kos doseže vrh mreže?
    private func pieceTouchesTopAfterPlacing() -> Bool {
        let piece = currentTetromino.rotations[currentRotation]
        for r in 0..<piece.count {
            for c in 0..<piece[r].count {
                if isFilled(piece[r][c]) {
                    let gridRow = Int(currentPosition.y) + r
                    if gridRow <= 0 {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // Pomožna funkcija: ali je celica polna (ni praznina)
    private func isFilled(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        // dovoli le znake kvadratkov
        let allowed = ["🟦", "🟨", "🟪", "🟩", "🟥", "🟧", "🟠"]
        return allowed.contains(trimmed)
    }

    private func holdPiece() {
        guard canHoldThisTurn else { return }
        let temp = heldTetromino
        heldTetromino = currentTetromino
        if let t = temp {
            currentTetromino = t
        } else {
            // no previous hold, spawn next
            currentTetromino = nextTetromino ?? tetrominoes.randomElement()!
            nextTetromino = tetrominoes.randomElement()!
        }
        currentRotation = 0
        currentPosition = CGPoint(x: 4, y: -4)
        canHoldThisTurn = false
        if !canPlacePiece() { gameOver() }
    }

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            gameTimer?.invalidate()
        } else {
            restartTimer()
        }
    }

    private func adjustTimerForSoftDrop() {
        guard !isPaused else { return }
        gameTimer?.invalidate()
        let interval = isSoftDropping ? max(0.05, dropInterval * 0.25) : dropInterval
        gameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if !isGameOver && rewardToday < maxRewardPerDay {
                moveDown()
            }
        }
    }

    private func restartTimer() {
        gameTimer?.invalidate()
        let interval = isSoftDropping ? max(0.05, dropInterval * 0.25) : dropInterval
        gameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if !isGameOver && rewardToday < maxRewardPerDay {
                moveDown()
            }
        }
    }
}

// MODEL ZA TETROMINO
struct Tetromino {
    let rotations: [[[String]]]
}

struct GridCellView: View {
    let content: String
    let cellSize: CGFloat
    let isClearing: Bool
    let isHighlighted: Bool

    var body: some View {
        Text(content)
            .font(.system(size: 26))
            .frame(width: cellSize, height: cellSize)
            .background(Color.black.opacity(0.8))
            .cornerRadius(4)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(isClearing ? 0.25 : 0))
            )
            .scaleEffect(isClearing ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.12), value: isClearing)
            .shadow(color: isHighlighted ? Color.yellow.opacity(0.6) : Color.clear, radius: 6)
            .animation(.easeOut(duration: 0.18), value: isHighlighted)
    }
}

struct CurrentPieceCellView: View {
    let content: String
    let cellSize: CGFloat

    var body: some View {
        Text(content)
            .font(.system(size: 26))
            .frame(width: cellSize, height: cellSize)
            .background(Color.black.opacity(0.9))
            .cornerRadius(4)
    }
}

struct Coin: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double
    var scale: CGFloat
    var rotation: Angle
}

struct CoinOverlayView: View {
    let coins: [Coin]
    var body: some View {
        ZStack {
            ForEach(coins) { coin in
                Image("btcz_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .opacity(coin.opacity)
                    .scaleEffect(coin.scale)
                    .rotationEffect(coin.rotation)
                    .position(coin.position)
            }
        }
    }
}

#Preview {
    BTCZTetrisView()
}


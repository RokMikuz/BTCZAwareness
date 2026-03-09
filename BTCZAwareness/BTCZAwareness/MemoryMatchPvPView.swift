import SwiftUI

struct MemoryMatchPvPView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    @State private var shakeIndices: [Int] = []
    
    enum Phase {
        case idle, matchmaking, waiting, playing, finished
    }
    
    @State private var phase: Phase = .idle
    @State private var matchId: String?
    @State private var boardSeed: [String] = []
    private let emojiPool = ["🐶","🦁","🦊","🐼","🐵","🐷","🦄","🐸","🐙","🐝","🦉","🐢","🐧","🐻","🐠","🐯"]
    
    struct PvPCard: Identifiable, Equatable {
        let id = UUID()
        let index: Int
        let state: String // "hidden" | "revealed" | "matched"
        let value: Int?
        let label: String?

        static func == (lhs: PvPCard, rhs: PvPCard) -> Bool {
            return lhs.index == rhs.index &&
                   lhs.state == rhs.state &&
                   lhs.value == rhs.value &&
                   lhs.label == rhs.label
        }
    }
    @State private var cards: [PvPCard] = []
    @State private var selectedIndices: [Int] = []
    @State private var playerRole: String? // "A" or "B"
    @State private var currentTurnRole: String? // "A" or "B"
    @State private var myScore: Int = 0
    @State private var oppScore: Int = 0
    @State private var bonusCost: Int = 0
    @State private var winReward: Int = 0
    @State private var isUsingBonus: Bool = false
    @State private var isFlipping: Bool = false
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>? = nil
    @State private var myBalanceLocal: Int = 0
    @State private var hasFinishedCalled: Bool = false
    
    // For animations in playing phase cards
    @State private var animateCardStates: [Int: Bool] = [:]
    
    // For finished phase animations
    @State private var finishedEmojiScale: CGFloat = 1.0
    @State private var finishedEmojiOpacity: Double = 0.0
    @State private var finishedTextOpacity: Double = 0.0
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var finishedEmojiShake: Bool = false
    
    private var isMyTurn: Bool {
        guard let me = playerRole, let turn = currentTurnRole else { return false }
        return me == turn
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Memory Match PvP")
                    .font(.largeTitle)
                    .bold()
                Text("1v1 head-to-head")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top)
            
            HStack(spacing: 12) {
                if phase == .playing {
                    Button("Use Bonus\(bonusCost > 0 ? " (\(bonusCost))" : "")") {
                        useBonus()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUsingBonus || !isMyTurn || myBalanceLocal < (winReward + bonusCost))
                }

                if phase == .playing {
                    Button(role: .destructive) {
                        if let id = matchId, !hasFinishedCalled {
                            hasFinishedCalled = true
                            ApiService.finishMemoryMatchPvP(matchId: id) { _, _ in
                                ApiService.getWalletBalance { _ in }
                            }
                        }
                        reset()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                            Text("Leave")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            contentView
            
            if phase == .playing {
                HStack(spacing: 40) {
                    VStack {
                        Text("You")
                            .font(.headline)
                        Text("\(myScore)")
                            .font(.title)
                    }
                    VStack {
                        Text("Opponent")
                            .font(.headline)
                        Text("\(oppScore)")
                            .font(.title)
                    }
                }
                .padding(.bottom)
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding()
        //.onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
        //    pollMatchState()
        //}
        .navigationTitle("Memory Match PvP")
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
        .onAppear {
            ApiService.getWalletBalance { bal in
                self.myBalanceLocal = bal
                ApiService.getConfig { cfg in
                    if let fee = cfg["tetris_pvp_entry_fee"] as? Int {
                        // Use as a generic entry gate if backend shares same key; optional
                        // Not directly used here, server handles true stake, but we can pre-check
                        if self.myBalanceLocal < fee { self.errorMessage = "Potrebuješ vsaj \(fee) BTCZ za vstop v PvP!" }
                    }
                    if let wr = cfg["win_reward"] as? Int { self.winReward = self.winReward == 0 ? wr : self.winReward }
                    if let bc = cfg["bonus_cost"] as? Int { self.bonusCost = self.bonusCost == 0 ? bc : self.bonusCost }
                }
            }
        }
        .onDisappear {
            // Cancel polling to prevent leaks
            pollingTask?.cancel()
            pollingTask = nil
            // If leaving while waiting, inform backend to clean queue
            if phase == .waiting, let id = matchId {
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                ApiService.leaveWaitingMemoryMatchPvP(matchId: id, deviceId: deviceId) { _, _ in }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch phase {
        case .idle:
            IdleMatchmakingView(startAction: startMatchmaking)
            
        case .matchmaking:
            ProgressView("Matching...")
                .padding(.top, 40)
            
        case .waiting:
            VStack(spacing: 16) {
                Text("Waiting for opponent...")
                    .font(.title3)
                HStack(spacing: 12) {
                    Button("Cancel") {
                        if let id = matchId {
                            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                            ApiService.leaveWaitingMemoryMatchPvP(matchId: id, deviceId: deviceId) { _, _ in }
                        }
                        cancelMatchmaking()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        reset()
                    } label: {
                        Text("Leave Match")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 40)
            
        case .playing:
            ZStack {
                // Animated gradient background with pulsing circles
                AnimatedGradientBackground()
                PulsingCircles()
                
                VStack(spacing: 16) {
                    Text(isMyTurn ? "Your turn" : (playerRole == "B" && currentTurnRole == "A" ? "Waiting for opponent (A) to start" : "Opponent's turn"))
                        .font(.headline)
                        .foregroundColor(isMyTurn ? .green : .gray)
                    Text("Win reward: \(winReward)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    let columns = Array(repeating: GridItem(.flexible()), count: 4)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(cards.sorted { $0.index < $1.index }) { card in
                            Button {
                                cardTapped(card.index)
                            } label: {
                                ZStack {
                                    Rectangle()
                                        .fill(colorFor(card: card))
                                        .cornerRadius(6)
                                        .frame(height: 60)
                                        .rotation3DEffect(.degrees(card.state == "revealed" || card.state == "matched" ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                                        .animation(.easeInOut(duration: 0.3), value: card.state)
                                        .modifier(ShakeEffect(shakes: shakeIndices.contains(card.index) ? 2 : 0))
                                        .scaleEffect(animateCardStates[card.index] == true ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.3), value: animateCardStates[card.index])
                                    if card.state != "hidden" {
                                        if let lbl = card.label {
                                            Text(lbl)
                                                .font(.title2)
                                                .bold()
                                                .foregroundColor(.white)
                                        } else if let val = card.value {
                                            Text("\(val)")
                                                .font(.title2)
                                                .bold()
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                            .disabled(phase != .playing || !isMyTurn || isFlipping || card.state != "hidden" || selectedIndices.contains(card.index) || selectedIndices.count == 2)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: cards) { newCards in
                guard phase == .playing else { return }
                // Animate card scale when their state changes to revealed or matched
                for card in newCards {
                    if card.state == "revealed" || card.state == "matched" {
                        animateCardStates[card.index] = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                animateCardStates[card.index] = false
                            }
                        }
                    }
                }
            }
            
        case .finished:
            ZStack {
                finishedBackground()
                    .ignoresSafeArea()
                    .animation(.easeIn(duration: 0.7), value: phase)
                
                VStack(spacing: 30) {
                    finishedEmoji()
                        .scaleEffect(finishedEmojiScale)
                        .opacity(finishedEmojiOpacity)
                        .modifier(emojiShakeEffect(shake: finishedEmojiShake))
                        .animation(.easeInOut(duration: 0.3), value: finishedEmojiScale)
                        .animation(.easeInOut(duration: 0.3), value: finishedEmojiOpacity)
                        .animation(.default, value: finishedEmojiShake)
                    
                    Text(winnerText())
                        .font(.title2)
                        .bold()
                        .opacity(finishedTextOpacity)
                        .animation(.easeIn(duration: 1.0), value: finishedTextOpacity)
                    
                    Button("Back") {
                        withAnimation {
                            reset()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if myScore > oppScore {
                    ConfettiView(particles: confettiParticles)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                // Server already sets finished/winner via flip/polling. Only refresh wallet balance.
                ApiService.getWalletBalance { bal in
                    self.myBalanceLocal = bal
                    if self.myScore > self.oppScore, self.winReward > 0 {
                        ApiService.addPoints(amount: self.winReward) { ok, _, newPoints in
                            if ok, let np = newPoints { self.myBalanceLocal = np }
                        }
                    }
                }
                
                // Animate finished phase elements
                finishedEmojiOpacity = 0
                finishedTextOpacity = 0
                finishedEmojiScale = 0.8
                finishedEmojiShake = false
                confettiParticles = []
                
                // Animate emoji scale and opacity
                withAnimation(.easeOut(duration: 0.8)) {
                    finishedEmojiOpacity = 1.0
                    finishedEmojiScale = 1.2
                }
                withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
                    finishedEmojiScale = 1.0
                    finishedTextOpacity = 1.0
                }
                
                // Confetti and shake animations depending on result
                if myScore > oppScore {
                    // Winner - launch confetti
                    generateConfetti()
                } else if oppScore > myScore {
                    // Loser - emoji shake and fade-in red background
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeInOut.repeatCount(3, autoreverses: true)) {
                            finishedEmojiShake.toggle()
                        }
                    }
                } else {
                    // Tie - emoji shake and fade-in blue background
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.easeInOut.repeatCount(3, autoreverses: true)) {
                            finishedEmojiShake.toggle()
                        }
                    }
                }
            }
        }
    }
    
    struct IdleMatchmakingView: View {
        let startAction: () -> Void
        var body: some View {
            ZStack {
                LinearGradient(colors: [
                    .orange.opacity(0.6),
                    .yellow.opacity(0.5),
                    .purple.opacity(0.5)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

                // Decorative circles
                CircleLayer()

                VStack(spacing: 28) {
                    Text("Head-To-Head")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .shadow(radius: 8)
                    Text("Fast PvP memory match game!")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.95))
                        .padding(.horizontal)
                    Text("🚀🧠✨")
                        .font(.system(size: 48))
                        .padding(.bottom, 8)
                    Button(action: startAction) {
                        IdleMatchButtonLabel()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    struct CircleLayer: View {
        var body: some View {
            ZStack {
                ForEach(0..<6) { i in
                    Circle()
                        .fill(Color.white.opacity(0.09))
                        .frame(width: CGFloat(120 + (i*17)), height: CGFloat(120 + (i*17)))
                        .position(x: CGFloat(40 + i*60), y: CGFloat(80 + i*35))
                        .blur(radius: 1.3)
                }
            }
        }
    }
    
    struct IdleMatchButtonLabel: View {
        var body: some View {
            HStack(spacing: 14) {
                Text("Quick Match")
                    .font(.title.bold())
                Text("⚡️")
                    .font(.title)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 50)
            .background(
                LinearGradient(colors: [
                    .yellow.opacity(0.92), .orange
                ], startPoint: .top, endPoint: .bottom)
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: .orange.opacity(0.33), radius: 12, x: 0, y: 7)
            .scaleEffect(0.98)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: UUID())
        }
    }
    
    // MARK: - Finished phase helpers and confetti
    
    private func finishedBackground() -> some View {
        Group {
            if myScore > oppScore {
                Color.green.opacity(0.6)
                    .transition(.opacity)
            } else if oppScore > myScore {
                Color.red.opacity(0.6)
                    .transition(.opacity)
            } else {
                Color.blue.opacity(0.6)
                    .transition(.opacity)
            }
        }
    }
    
    private func finishedEmoji() -> some View {
        Group {
            if myScore > oppScore {
                Text("🎉")
                    .font(.system(size: 120))
                    .shadow(radius: 8)
            } else if oppScore > myScore {
                Text("😞")
                    .font(.system(size: 120))
                    .shadow(radius: 8)
            } else {
                Text("🤝")
                    .font(.system(size: 120))
                    .shadow(radius: 8)
            }
        }
    }
    
    private func generateConfetti() {
        // Initialize particles once; ConfettiView handles per-particle animation onAppear using its own delay
        confettiParticles = (0..<30).map { _ in ConfettiParticle.random() }
    }
    
    private func emojiShakeEffect(shake: Bool) -> some ViewModifier {
        return ShakeEffect(shakes: shake ? 4 : 0, amplitude: 8)
    }
    
    // MARK: - Animated Playing phase background and circles
    
    struct AnimatedGradientBackground: View {
        @State private var animate = false
        
        var body: some View {
            LinearGradient(
                gradient: Gradient(colors: [
                    .orange.opacity(0.6),
                    .yellow.opacity(0.5),
                    .purple.opacity(0.5),
                    .orange.opacity(0.6)
                ]),
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(Animation.linear(duration: 8).repeatForever(autoreverses: true), value: animate)
            .onAppear {
                animate.toggle()
            }
        }
    }
    
    struct PulsingCircles: View {
        @State private var pulse = false
        
        var body: some View {
            ZStack {
                ForEach(0..<6) { i in
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: CGFloat(120 + (i*17)), height: CGFloat(120 + (i*17)))
                        .position(x: CGFloat(40 + i*60), y: CGFloat(80 + i*35))
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .opacity(pulse ? 0.12 : 0.08)
                        .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(i)*0.2), value: pulse)
                }
            }
            .onAppear {
                pulse.toggle()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func colorFor(card: PvPCard) -> Color {
        switch card.state {
        case "matched": return Color.green.opacity(0.7)
        case "revealed": return Color.blue.opacity(0.7)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private func startMatchmaking() {
        // New guard at very start
        if myBalanceLocal < winReward {
            errorMessage = "Potrebuješ vsaj \(winReward) BTCZ za vstop v PvP!"
            return
        }
        
        ApiService.getConfig { cfg in
            let entryFee = (cfg["tetris_pvp_entry_fee"] as? Int) ?? 0
            if entryFee > 0 {
                ApiService.addPoints(amount: -entryFee) { ok, msg, newPoints in
                    if ok, let np = newPoints { self.myBalanceLocal = np }
                }
            }
        }
        
        phase = .matchmaking
        errorMessage = nil
        ApiService.createMemoryMatchPvP { ok, json in
            DispatchQueue.main.async {
                guard ok, let json = json else {
                    self.phase = .idle
                    self.errorMessage = "Server unavailable"
                    return
                }
                self.matchId = json["match_id"] as? String
                self.playerRole = json["player"] as? String

                // Robust parsing for bonusCost and winReward
                if let bc = json["bonus_cost"] as? Int { self.bonusCost = bc }
                else if let bcStr = json["bonus_cost"] as? String, let bc = Int(bcStr) { self.bonusCost = bc }
                else { self.bonusCost = 0 }

                if let wrAny = json["win_reward"] {
                    if let wr = wrAny as? Int { self.winReward = wr }
                    else if let wrStr = wrAny as? String { self.winReward = Int(wrStr) ?? 100 }
                    else { self.winReward = 100 }
                } else {
                    self.winReward = 100
                }

                if let seedStr = json["board_seed"] as? String {
                    self.boardSeed = seedStr.split(separator: ",").map { String($0) }
                } else {
                    let pairCount = 8
                    var chars = (0..<pairCount).flatMap { i in [String(UnicodeScalar(65+i)!), String(UnicodeScalar(65+i)!)] }
                    chars.shuffle()
                    self.boardSeed = chars
                }
                
                let status = (json["status"] as? String) ?? "waiting"
                if status == "playing" {
                    self.phase = .playing
                } else {
                    self.phase = .waiting
                }
                startPolling()
            }
        }
    }
    
    private func cancelMatchmaking() {
        phase = .idle
        matchId = nil
        errorMessage = nil
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    private func cardTapped(_ index: Int) {
        guard phase == .playing else { return }
        let validCount = cards.count
        guard index >= 0 && index < validCount else { return }
        
        guard isMyTurn, !isFlipping, selectedIndices.count < 2 else { return }
        
        // If first card tapped, just reveal it and do nothing else yet
        if selectedIndices.isEmpty {
            selectedIndices.append(index)
            cards = cards.map { card in
                if card.index == index {
                    return PvPCard(index: card.index, state: "revealed", value: card.value, label: card.label)
                } else {
                    return card
                }
            }
            // Also inform server about the first flip with a single index so it keeps the card revealed
            guard let id = matchId else { return }
            let toFlipFirst = [index]
            ApiService.flipMemoryMatchPvP(matchId: id, indices: toFlipFirst) { ok, json in
                DispatchQueue.main.async {
                    guard ok, let json = json else {
                        self.errorMessage = "Failed to flip card."
                        // Revert local selection on failure
                        self.selectedIndices.removeAll()
                        // Optionally reset or refetch state
                        self.forcePollOnce()
                        return
                    }
                    // Update board from server to keep single revealed state authoritative
                    if let updatedCSV = json["updated_board"] as? String {
                        self.cards = parseBoardCSV(updatedCSV)
                    } else if let updated = json["updated_board"] as? [[String: Any]] {
                        self.cards = parseBoard(updated)
                    }
                    // Update scores if present
                    if let scores = json["scores"] as? [String: Any] {
                        self.myScore = (scores["me"] as? Int) ?? self.myScore
                        self.oppScore = (scores["opp"] as? Int) ?? self.oppScore
                    } else {
                        self.myScore = json["my_score"] as? Int ?? self.myScore
                        self.oppScore = json["opp_score"] as? Int ?? self.oppScore
                    }
                    // Update turn if provided (server may or may not switch turn on single flip)
                    if let turn = json["player_turn"] as? String {
                        self.currentTurnRole = turn
                    }
                }
            }
            return
        }
        
        // When second card tapped:
        isFlipping = true
        selectedIndices.append(index)
        cards = cards.map { card in
            if selectedIndices.contains(card.index) {
                return PvPCard(index: card.index, state: "revealed", value: card.value, label: card.label)
            } else {
                return card
            }
        }
        
        guard let id = matchId else {
            isFlipping = false
            selectedIndices.removeAll()
            return
        }
        
        let toFlip = selectedIndices
        ApiService.flipMemoryMatchPvP(matchId: id, indices: toFlip) { ok, json in
            DispatchQueue.main.async {
                guard ok, let json = json else {
                    self.errorMessage = "Failed to flip cards."
                    self.isFlipping = false
                    self.selectedIndices.removeAll()
                    self.shakeIndices = []
                    self.reset()
                    return
                }
                // Update board
                if let updatedCSV = json["updated_board"] as? String {
                    self.cards = parseBoardCSV(updatedCSV)
                } else if let updated = json["updated_board"] as? [[String: Any]] {
                    self.cards = parseBoard(updated)
                }
                
                // Use server response to set shakeIndices only if cards did not match and indices are valid in current cards
                let validToFlip = toFlip.filter { idx in self.cards.contains(where: { $0.index == idx }) }
                if validToFlip.filter({ idx in self.cards.first(where: { $0.index == idx })?.state == "matched" }).count < 2 {
                    self.shakeIndices = validToFlip
                } else {
                    self.shakeIndices = []
                }
                self.isFlipping = false
                
                // Update scores
                if let scores = json["scores"] as? [String: Any] {
                    self.myScore = (scores["me"] as? Int) ?? self.myScore
                    self.oppScore = (scores["opp"] as? Int) ?? self.oppScore
                } else {
                    self.myScore = json["my_score"] as? Int ?? self.myScore
                    self.oppScore = json["opp_score"] as? Int ?? self.oppScore
                }
                // Update turn
                if let turn = json["player_turn"] as? String {
                    self.currentTurnRole = turn
                }
                self.selectedIndices.removeAll()
            }
        }
    }
    
    private func useBonus() {
        guard let id = matchId, isMyTurn, !isUsingBonus else { return }
        isUsingBonus = true
        errorMessage = nil
        ApiService.useBonusMemoryMatchPvP(matchId: id) { ok, json in
            DispatchQueue.main.async {
                self.isUsingBonus = false
                guard ok, let json = json else {
                    self.errorMessage = "Failed to use bonus."
                    return
                }
                if let updatedCSV = json["updated_board"] as? String {
                    self.cards = parseBoardCSV(updatedCSV)
                } else if let updated = json["updated_board"] as? [[String: Any]] {
                    self.cards = parseBoard(updated)
                }
                if let scores = json["scores"] as? [String: Any] {
                    self.myScore = (scores["me"] as? Int) ?? self.myScore
                    self.oppScore = (scores["opp"] as? Int) ?? self.oppScore
                }
                if let turn = json["player_turn"] as? String {
                    self.currentTurnRole = turn
                }
                if self.bonusCost > 0 {
                    ApiService.addPoints(amount: -self.bonusCost) { ok, _, newPoints in
                        if ok, let np = newPoints { self.myBalanceLocal = np }
                    }
                }
                // Ensure we are fully in sync with server state after bonus
                self.forcePollOnce()
                ApiService.getWalletBalance { bal in
                    self.myBalanceLocal = bal
                }
            }
        }
    }
    
    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { await pollLoop() }
    }
    
    private func forcePollOnce() {
        guard let id = matchId else { return }
        ApiService.getMemoryMatchPvPState(matchId: id) { ok, json in
            DispatchQueue.main.async {
                if ok, let json = json {
                    if let status = json["status"] as? String {
                        if status == "playing" { self.phase = .playing }
                        if status == "finished" {
                            self.phase = .finished
                        }
                    }
                    if let turn = json["player_turn"] as? String { self.currentTurnRole = turn }
                    if let boardCSV = json["board"] as? String {
                        self.cards = parseBoardCSV(boardCSV)
                    } else if let updated = json["board"] as? [[String: Any]] {
                        self.cards = parseBoard(updated)
                    }
                    self.myScore = (json["my_score"] as? Int) ?? self.myScore
                    self.oppScore = (json["opp_score"] as? Int) ?? self.oppScore

                    // Robust parsing for bonusCost and winReward
                    if let bc = json["bonus_cost"] as? Int { self.bonusCost = bc }
                    else if let bcStr = json["bonus_cost"] as? String, let bc = Int(bcStr) { self.bonusCost = bc }

                    if let wrAny = json["win_reward"] {
                        if let wr = wrAny as? Int { self.winReward = wr }
                        else if let wrStr = wrAny as? String { self.winReward = Int(wrStr) ?? self.winReward }
                    }

                    if let status = json["status"] as? String, status == "finished" {
                        self.selectedIndices.removeAll()
                        self.isFlipping = false
                        self.shakeIndices = []
                        self.pollingTask?.cancel()
                        self.pollingTask = nil
                        ApiService.getWalletBalance { _ in }
                    }
                    if self.phase == .finished {
                        ApiService.getWalletBalance { _ in }
                    }
                }
            }
        }
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            guard let id = matchId, phase == .waiting || phase == .playing else { break }
            await withCheckedContinuation { continuation in
                ApiService.getMemoryMatchPvPState(matchId: id) { ok, json in
                    DispatchQueue.main.async {
                        if ok, let json = json {
                            if let status = json["status"] as? String {
                                if status == "playing" {
                                    self.phase = .playing
                                }
                                if status == "finished" {
                                    self.phase = .finished
                                    self.selectedIndices.removeAll()
                                    self.isFlipping = false
                                    self.shakeIndices = []
                                    self.pollingTask?.cancel()
                                    self.pollingTask = nil
                                    ApiService.getWalletBalance { _ in }
                                }
                            }
                            if let turn = json["player_turn"] as? String { self.currentTurnRole = turn }
                            if let boardCSV = json["board"] as? String {
                                self.cards = parseBoardCSV(boardCSV)
                            } else if let updated = json["board"] as? [[String: Any]] {
                                self.cards = parseBoard(updated)
                            }
                            self.myScore = (json["my_score"] as? Int) ?? self.myScore
                            self.oppScore = (json["opp_score"] as? Int) ?? self.oppScore

                            // Robust parsing for bonusCost and winReward
                            if let bc = json["bonus_cost"] as? Int { self.bonusCost = bc }
                            else if let bcStr = json["bonus_cost"] as? String, let bc = Int(bcStr) { self.bonusCost = bc }

                            if let wrAny = json["win_reward"] {
                                if let wr = wrAny as? Int { self.winReward = wr }
                                else if let wrStr = wrAny as? String { self.winReward = Int(wrStr) ?? self.winReward }
                            }
                        }
                        continuation.resume()
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if phase == .finished { break }
        }
    }
    
    private func emojiFor(label: String?) -> String? {
        guard let label = label, let ascii = label.unicodeScalars.first?.value, ascii >= 65 else { return nil }
        let idx = Int(ascii - 65)
        return idx < emojiPool.count ? emojiPool[idx] : nil
    }
    
    private func parseBoard(_ arr: [[String: Any]]) -> [PvPCard] {
        arr.compactMap { dict in
            let index = dict["index"] as? Int ?? 0
            let state = dict["state"] as? String ?? "hidden"
            let value = dict["value"] as? Int
            let charLabel: String? = index < boardSeed.count ? boardSeed[index] : nil
            let label: String? = emojiFor(label: charLabel)
            return PvPCard(index: index, state: state, value: value, label: label)
        }.sorted { $0.index < $1.index }
    }

    private func parseBoardCSV(_ csv: String) -> [PvPCard] {
        let parts = csv.split(separator: ",").map { String($0) }
        return parts.enumerated().map { (idx, state) in
            let charLabel: String? = idx < boardSeed.count ? boardSeed[idx] : nil
            let label: String? = emojiFor(label: charLabel)
            return PvPCard(index: idx, state: state, value: nil, label: label)
        }
    }
    
    private func winnerText() -> String {
        if myScore > oppScore {
            return "You won! 🎉"
        } else if oppScore > myScore {
            return "You lost. 😞"
        } else {
            return "It's a tie."
        }
    }
    
    private func reset() {
        phase = .idle
        matchId = nil
        cards = []
        selectedIndices = []
        playerRole = nil
        currentTurnRole = nil
        myScore = 0
        oppScore = 0
        bonusCost = 0
        winReward = 0
        isUsingBonus = false
        isFlipping = false
        errorMessage = nil
        shakeIndices = []
        pollingTask?.cancel()
        pollingTask = nil
        animateCardStates = [:]
        finishedEmojiScale = 1.0
        finishedEmojiOpacity = 0.0
        finishedTextOpacity = 0.0
        confettiParticles = []
        finishedEmojiShake = false
        hasFinishedCalled = false
    }
    
    //private func pollMatchState() {
    //    guard let id = matchId, phase == .playing else { return }
    //    // Placeholder for ApiService.getMemoryMatchPvPState(matchId: id)
    //}
}

// MARK: - Confetti

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var xPosition: CGFloat
    var size: CGFloat
    var color: Color
    var falling: Bool = false
    var delay: Double = 0
    var speed: Double = 1.0
    
    static func random() -> ConfettiParticle {
        let screenWidth = UIScreen.main.bounds.width
        return ConfettiParticle(
            xPosition: CGFloat.random(in: 0...screenWidth),
            size: CGFloat.random(in: 8...16),
            color: [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple].randomElement() ?? .red,
            delay: Double.random(in: 0...1),
            speed: Double.random(in: 1.5...3.0)
        )
    }
}

struct ConfettiView: View {
    @State var particles: [ConfettiParticle]
    @State private var yOffsets: [UUID: CGFloat] = [:]
    @State private var opacities: [UUID: Double] = [:]
    
    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(x: particle.xPosition, y: yOffsets[particle.id] ?? -20)
                    .opacity(opacities[particle.id] ?? 1.0)
                    .onAppear {
                        yOffsets[particle.id] = -20
                        opacities[particle.id] = 1.0
                        // Start the fall after the particle's own delay; repeat forever
                        withAnimation(Animation.linear(duration: particle.speed).delay(particle.delay).repeatForever(autoreverses: false)) {
                            yOffsets[particle.id] = geo.size.height + 20
                            opacities[particle.id] = 0.0
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shake Effect

struct ShakeEffect: GeometryEffect {
    var shakes: Int
    var amplitude: CGFloat = 8
    var animatableData: CGFloat {
        get { CGFloat(shakes) }
        set { shakes = Int(newValue) }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(.pi * animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct MemoryMatchPvPView_Previews: PreviewProvider {
    static var previews: some View {
        MemoryMatchPvPView()
    }
}


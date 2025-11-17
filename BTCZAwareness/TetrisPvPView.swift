import SwiftUI

struct TetrisPvPView: View {
    enum Phase { case idle, matchmaking, waiting, playing, finished }

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .idle
    @State private var backPressed = false

    @State private var matchId: String?
    @State private var playerRole: String? // "A" or "B"
    @State private var opponentJoined: Bool = false
    @State private var seed: String? = nil

    @State private var entryFee: Int = 0
    @State private var winReward: Int = 0

    @State private var myScore: Int = 0
    @State private var oppScore: Int = 0
    @State private var myLines: Int = 0
    @State private var oppLines: Int = 0

    @State private var errorMessage: String?

    @State private var pollingTask: Task<Void, Never>? = nil
    
    @State private var localTick: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            header
            content
            if let err = errorMessage {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
        .navigationTitle("Tetris PvP")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    backPressed = true
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {}
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
        .onDisappear { pollingTask?.cancel(); pollingTask = nil }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Entry: \(entryFee)")
            Text("Win: \(winReward)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            VStack(spacing: 12) {
                Text("Quick Match")
                    .font(.title.bold())
                Button("Find Opponent") { startMatchmaking() }
                    .buttonStyle(.borderedProminent)
            }
            .onAppear { loadConfig() }

        case .matchmaking:
            ProgressView("Matching...")
                .task { startPolling() }

        case .waiting:
            VStack(spacing: 12) {
                Text("Waiting for opponent...")
                Button("Cancel") { cancelMatchmaking() }
                    .buttonStyle(.bordered)
            }

        case .playing:
            VStack(spacing: 12) {
                Text("\(playerRole == currentTurn ? "Your" : "Opponent's") turn")
                    .foregroundStyle(playerRole == currentTurn ? .green : .gray)
                HStack(spacing: 24) {
                    VStack { Text("You").font(.headline); Text("\(myScore)") }
                    VStack { Text("Opponent").font(.headline); Text("\(oppScore)") }
                }
                HStack(spacing: 24) {
                    VStack { Text("Your lines"); Text("\(myLines)") }
                    VStack { Text("Opp lines"); Text("\(oppLines)") }
                }
                // Updated control buttons with adaptive sizing and SF Symbols
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                let minTap: CGFloat = isPad ? 56 : 48
                let maxTap: CGFloat = isPad ? 88 : 72
                let base: CGFloat = isPad ? 64 : 56
                let iconSize = max(minTap, min(maxTap, base))
                let sideSpacing: CGFloat = isPad ? 60 : 40
                let verticalSpacing: CGFloat = isPad ? 14 : 10

                if isPad {
                    HStack(spacing: 24) {
                        // Left at far left
                        Button { sendMove("left") } label: {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.orange)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Move Left")

                        Spacer(minLength: 20)

                        // Center pair: Rotate + Hard Drop
                        HStack(spacing: 36) {
                            Button { sendMove("rotate") } label: {
                                Image(systemName: "rotate.right.fill")
                                    .font(.system(size: iconSize))
                                    .foregroundStyle(.yellow)
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Rotate")

                            Button { sendMove("hard_drop") } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: max(iconSize, minTap + 6)))
                                    .foregroundStyle(.red)
                                    .padding(10)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Hard Drop")
                        }

                        Spacer(minLength: 20)

                        // Right at far right
                        Button { sendMove("right") } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.orange)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Move Right")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, verticalSpacing)
                } else {
                    HStack(spacing: sideSpacing) {
                        Button { sendMove("left") } label: {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.orange)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Move Left")

                        VStack(spacing: verticalSpacing) {
                            Button { sendMove("rotate") } label: {
                                Image(systemName: "rotate.right.fill")
                                    .font(.system(size: iconSize))
                                    .foregroundStyle(.yellow)
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Rotate")

                            Button { sendMove("hard_drop") } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: max(iconSize, minTap + 6)))
                                    .foregroundStyle(.red)
                                    .padding(10)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Hard Drop")
                        }

                        Button { sendMove("right") } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: iconSize))
                                .foregroundStyle(.orange)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Move Right")
                    }
                    .padding(.horizontal, isPad ? 24 : 16)
                    .padding(.bottom, isPad ? 14 : 10)
                }

                Button {
                    useBonus()
                } label: {
                    Label("Use Bonus", systemImage: "sparkles")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }

        case .finished:
            VStack(spacing: 16) {
                Text(winner == playerRole ? "You won!" : "You lost")
                    .font(.title.bold())
                Button("Back") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .onAppear { refreshBalance() }
        }
    }

    // MARK: - Server state
    @State private var currentTurn: String? = nil
    @State private var winner: String? = nil

    private func loadConfig() {
        ApiService.getConfig { cfg in
            if let fee = cfg["tetris_pvp_entry_fee"] as? Int { self.entryFee = fee }
            else if let feeStr = cfg["tetris_pvp_entry_fee"] as? String { self.entryFee = Int(feeStr) ?? self.entryFee }
            if let wr = cfg["tetris_pvp_win_reward"] as? Int { self.winReward = wr }
            else if let wrStr = cfg["tetris_pvp_win_reward"] as? String { self.winReward = Int(wrStr) ?? self.winReward }
        }
    }

    private func startMatchmaking() {
        phase = .matchmaking
        ApiService.createTetrisPvP { ok, json in
            DispatchQueue.main.async {
                guard ok, let json = json else { self.phase = .idle; self.errorMessage = "Server unavailable"; return }
                self.matchId = json["match_id"] as? String
                self.playerRole = json["player"] as? String
                self.seed = json["seed"] as? String
                if let fee = json["entry_fee"] as? Int { self.entryFee = fee }
                else if let feeStr = json["entry_fee"] as? String { self.entryFee = Int(feeStr) ?? self.entryFee }
                if let wr = json["win_reward"] as? Int { self.winReward = wr }
                else if let wrStr = json["win_reward"] as? String { self.winReward = Int(wrStr) ?? self.winReward }
                let status = (json["status"] as? String) ?? "waiting"
                self.phase = (status == "playing") ? .playing : .waiting

                if let s = self.seed, let id = self.matchId {
                    NotificationCenter.default.post(name: Notification.Name("TetrisSeedReady"), object: nil, userInfo: [
                        "seed": s,
                        "match_id": id,
                        "player_role": self.playerRole as Any,
                        "player_turn": self.currentTurn as Any
                    ])
                }

                if self.entryFee > 0 {
                    ApiService.addPoints(amount: -self.entryFee) { ok, _, _ in
                        // Balance will be refreshed via server polling/other flows
                    }
                }

                startPolling()
            }
        }
    }

    private func cancelMatchmaking() {
        guard let id = matchId else { phase = .idle; return }
        ApiService.leaveTetrisPvP(matchId: id) { _, _ in }
        phase = .idle
        pollingTask?.cancel(); pollingTask = nil
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { await pollLoop() }
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            guard let id = matchId else { break }
            await withCheckedContinuation { cont in
                ApiService.getTetrisPvPState(matchId: id) { ok, json in
                    DispatchQueue.main.async {
                        if ok, let json = json {
                            if let status = json["status"] as? String {
                                switch status {
                                case "waiting": self.phase = .waiting
                                case "playing": self.phase = .playing
                                case "finished":
                                    self.phase = .finished
                                    if let w = self.winner, let me = self.playerRole, w == me, self.winReward > 0 {
                                        ApiService.addPoints(amount: self.winReward) { _, _, _ in }
                                    }
                                default: break
                                }
                            }
                            self.currentTurn = (json["player_turn"] as? String) ?? (json["player_role"] as? String)
                            self.opponentJoined = (json["opponent_joined"] as? Bool) ?? self.opponentJoined
                            if let s = json["seed"] as? String { self.seed = s }
                            self.myScore = (json["my_score"] as? Int) ?? self.myScore
                            self.oppScore = (json["opp_score"] as? Int) ?? self.oppScore
                            self.myLines = (json["my_lines"] as? Int) ?? self.myLines
                            self.oppLines = (json["opp_lines"] as? Int) ?? self.oppLines
                            if let w = json["winner"] as? String { self.winner = w }

                            if let s = self.seed, let id = self.matchId {
                                NotificationCenter.default.post(name: Notification.Name("TetrisSeedReady"), object: nil, userInfo: [
                                    "seed": s,
                                    "match_id": id,
                                    "player_role": self.playerRole as Any,
                                    "player_turn": self.currentTurn as Any
                                ])
                            }
                        }
                        cont.resume()
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if phase == .finished { break }
        }
    }
    
    private func sendMove(_ move: String) {
        guard let id = matchId else { return }
        localTick += 1
        ApiService.tetrisPvPMove(matchId: id, move: move, tick: localTick) { _, _ in }
    }
    
    private func reportLinesCleared(_ lines: Int, combo: Int? = nil) {
        guard let id = matchId else { return }
        localTick += 1
        ApiService.tetrisPvPLinesCleared(matchId: id, lines: lines, combo: combo, tick: localTick) { ok, json in
            DispatchQueue.main.async {
                if ok, let json = json {
                    if let myTotal = json["my_total_lines"] as? Int { self.myLines = myTotal }
                    if let myScore = json["my_score"] as? Int { self.myScore = myScore }
                }
            }
        }
    }

    private func refreshBalance() {
        ApiService.getWalletBalance { _ in }
    }

    private func useBonus() {
        ApiService.getConfig { cfg in
            let bonusCost: Int = (cfg["bonus_cost"] as? Int) ?? 0
            if bonusCost > 0 {
                ApiService.addPoints(amount: -bonusCost) { _, _, _ in }
            }
        }
    }
}

#Preview {
    NavigationStack { TetrisPvPView() }
}

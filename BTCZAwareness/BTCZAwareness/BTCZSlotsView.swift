// BTCZSlotsView.swift – 100 % CELOTNA – LEPŠE ANIMACIJE + 20 SPINOV/DAN + MANJŠI REŽI + POPRAVLJENE PISAVE
import SwiftUI
import Combine

struct BTCZSlotsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    // SIMBOLI
    private let symbols = ["🪙", "💰", "💎", "🎰", "7️⃣", "🔥", "🌟", "🚀"]
    
    @State private var reel1: String = "🪙"
    @State private var reel2: String = "🪙"
    @State private var reel3: String = "🪙"
    
    @State private var isSpinning = false
    @State private var showWinAnimation = false
    @State private var winMessage = ""
    @State private var winAmount = 0
    @State private var sparklePositions: [CGPoint] = []
    
    // SPINNING STATE
    @State private var reelIndex1: Int = 0
    @State private var reelIndex2: Int = 0
    @State private var reelIndex3: Int = 0
    @State private var reel1Spinning: Bool = false
    @State private var reel2Spinning: Bool = false
    @State private var reel3Spinning: Bool = false
    @State private var spinStart: Date?
    let spinTicker = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()
    
    // 20 SPINOV NA DAN (vsi plačljivi po 10 BTCZ)
    private let spinCost = 10
    private let maxSpinsPerDay = 20
    @State private var spinsToday = 0
    @State private var lastSpinDate: Date? = UserDefaults.standard.object(forKey: "slotsLastSpin") as? Date
    
    var canSpin: Bool {
        spinsToday < maxSpinsPerDay && PointsManager.shared.currentPoints >= spinCost
    }
    
    var spinsLeftString: String {
        "\(maxSpinsPerDay - spinsToday) spins left today"
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.9), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 35) {
                // BALANCE
                Text("Balance: \(PointsManager.shared.currentPoints) BTCZ")
                    .font(.title.bold())
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.8), radius: 10)
                
                // SPINS LEFT
                Text(spinsLeftString)
                    .font(.title3)
                    .foregroundStyle(canSpin ? .orange : .red.opacity(0.8))
                
                // REŽI – MANJŠI IN LEPŠI
                HStack(spacing: 20) {
                    ReelView(symbol: reel1)
                    ReelView(symbol: reel2)
                    ReelView(symbol: reel3)
                }
                .frame(height: 120)
                .padding(.horizontal, 40)
                .background(.black.opacity(0.7))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.yellow.opacity(0.9), lineWidth: 4)
                )
                .shadow(color: .yellow.opacity(0.7), radius: 20)
                
                // WIN MESSAGE + ANIMACIJA
                if showWinAnimation {
                    VStack(spacing: 10) {
                        Text(winMessage)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.9), radius: 20)
                            .scaleEffect(showWinAnimation ? 1.3 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true), value: showWinAnimation)
                        
                        Text("+\(winAmount) BTCZ")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.9), radius: 20)
                    }
                }
                
                // SPIN GUMB
                Button("SPIN FOR \(spinCost) BTCZ") {
                    spin()
                }
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    canSpin
                        ? LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )                .cornerRadius(20)
                .shadow(color: canSpin ? .purple.opacity(0.6) : .clear, radius: 15)
                .padding(.horizontal, 40)
                .disabled(!canSpin)
                
                Spacer()
            }
            .onAppear {
                checkDailySpins()
            }
            .onReceive(spinTicker) { _ in
                guard isSpinning, let start = spinStart else { return }
                let elapsed = Date().timeIntervalSince(start)
                
                // Durations for each reel (staggered stops)
                let d1: TimeInterval = 1.6
                let d2: TimeInterval = 2.0
                let d3: TimeInterval = 2.4
                
                if reel1Spinning {
                    reelIndex1 = (reelIndex1 + 1) % symbols.count
                    reel1 = symbols[reelIndex1]
                    if elapsed >= d1 { reel1Spinning = false }
                }
                
                if reel2Spinning {
                    reelIndex2 = (reelIndex2 + 1) % symbols.count
                    reel2 = symbols[reelIndex2]
                    if elapsed >= d2 { reel2Spinning = false }
                }
                
                if reel3Spinning {
                    reelIndex3 = (reelIndex3 + 1) % symbols.count
                    reel3 = symbols[reelIndex3]
                    if elapsed >= d3 { reel3Spinning = false }
                }
                
                // When all reels have stopped, finalize the spin
                if !reel1Spinning && !reel2Spinning && !reel3Spinning {
                    isSpinning = false
                    checkWin()
                }
            }
            .navigationTitle("BTCZ Slots")
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
            
            // SPARKLE EFEKT PRI WINU
            ZStack {
                ForEach(sparklePositions, id: \.self) { position in
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)
                        .position(position)
                        .opacity(0.9)
                        .scaleEffect(0)
                        .animation(.easeOut(duration: 1.2), value: UUID())
                }
            }
        }
    }
    
    private func spin() {
        guard !isSpinning && canSpin else { return }
        
        isSpinning = true
        showWinAnimation = false
        
        // Deduct cost and persist via server
        ApiService.addPoints(amount: -spinCost) { ok, _, newPoints in
            if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
        }
        
        // Track daily spins
        spinsToday += 1
        UserDefaults.standard.set(Date(), forKey: "slotsLastSpin")
        UserDefaults.standard.set(spinsToday, forKey: "slotsSpinsToday")
        
        // Start spinning
        spinStart = Date()
        reel1Spinning = true
        reel2Spinning = true
        reel3Spinning = true
    }
    
    private func checkWin() {
        let roll = Double.random(in: 0...1)
        
        // First gate: only allow any win with a lower probability
        if roll < 0.12 { // ~12% chance any win happens
            if reel1 == reel2 && reel2 == reel3 {
                let multiplier: Int
                switch reel1 {
                case "🪙": multiplier = 5
                case "💰": multiplier = 10
                case "💎": multiplier = 20
                case "🎰": multiplier = 50
                case "7️⃣": multiplier = 100
                case "🔥": multiplier = 200
                case "🌟": multiplier = 500
                case "🚀": multiplier = 1000
                default: multiplier = 3
                }
                winAmount = multiplier * 10
                winMessage = "JACKPOT!!!"
            } else if (reel1 == reel2) || (reel2 == reel3) || (reel1 == reel3) {
                // Pair win happens only if gated and pairs match
                winAmount = 10 // reduce pair win amount for lower impact
                winMessage = "Nice Win!"
            } else {
                winAmount = 0
                winMessage = "Try Again!"
            }
        } else {
            // Gate failed: no win regardless of reels
            winAmount = 0
            winMessage = "Try Again!"
        }
        
        if winAmount > 0 {
            ApiService.addPoints(amount: winAmount) { ok, _, newPoints in
                if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
            }
            addSparkles()
        }
        
        showWinAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showWinAnimation = false
        }
    }
    
    private func addSparkles() {
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        for _ in 0..<20 {
            let angle = Double.random(in: 0..<2 * .pi)
            let distance = Double.random(in: 100...250)
            let x = center.x + distance * cos(angle)
            let y = center.y + distance * sin(angle)
            sparklePositions.append(CGPoint(x: x, y: y))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sparklePositions = []
        }
    }
    
    private func checkDailySpins() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastSpinDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if calendar.isDate(today, inSameDayAs: lastDay) {
                spinsToday = UserDefaults.standard.integer(forKey: "slotsSpinsToday")
            } else {
                spinsToday = 0
                UserDefaults.standard.set(0, forKey: "slotsSpinsToday")
            }
        } else {
            spinsToday = 0
        }
        
        UserDefaults.standard.set(spinsToday, forKey: "slotsSpinsToday")
    }
}

// REEL VIEW – MANJŠI IN LEPŠI
struct ReelView: View {
    let symbol: String
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 80))
            .frame(width: 100, height: 100)
            .background(.black.opacity(0.7))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.yellow.opacity(0.9), lineWidth: 4)
            )
            .shadow(color: .yellow.opacity(0.7), radius: 15)
    }
}

#Preview {
    BTCZSlotsView()
}
